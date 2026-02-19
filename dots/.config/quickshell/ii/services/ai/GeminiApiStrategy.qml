import QtQuick
import qs.modules.common.functions as CF
ApiStrategy {
    readonly property string apiKeyEnvVarName: "API_KEY"
    readonly property string fileDataVarName: "BASE64_DATA"
    readonly property string fileMimeTypeVarName: "MIME_TYPE"
    readonly property string fileDataSubstitutionString: "{{ fileDataVarName }}"
    readonly property string fileMimeTypeSubstitutionString: "{{ fileMimeTypeVarName }}"
    property string buffer: ""

    function buildEndpoint(model: AiModel): string {
        // Replace the base URL with ProxyAPI's Google proxy base
        const proxyBase = "https://api.proxyapi.ru/google/v1beta/";
        const originalEndpoint = model.endpoint.replace("https://generativelanguage.googleapis.com/v1beta/", proxyBase);
        const result = originalEndpoint + `?key=\$\{${root.apiKeyEnvVarName}\}`;
        // console.log("[AI] Endpoint: " + result);
        return result;
    }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let contents = messages.map(message => {
            // console.log("[AI] Building request data for message:", JSON.stringify(message, null, 2));
            const geminiApiRoleName = (message.role === "assistant") ? "model" : message.role;
            const usingSearch = tools[0]?.google_search !== undefined
            if (!usingSearch && message.functionCall != undefined && message.functionName.length > 0) {
                return {
                    "role": geminiApiRoleName,
                    "parts": [{
                        functionCall: {
                            "name": message.functionName,
                        }
                    }]
                }
            }
            if (!usingSearch && message.functionResponse != undefined && message.functionName.length > 0) {
                return {
                    "role": geminiApiRoleName,
                    "parts": [{
                        functionResponse: {
                            "name": message.functionName,
                            "response": { "content": message.functionResponse }
                        }
                    }]
                }
            }
            return {
                "role": geminiApiRoleName,
                "parts": [
                    { text: message.rawContent },
                    ...(message.fileUri && message.fileUri.length > 0 ? [{
                        "file_data": {
                            "mime_type": message.fileMimeType,
                            "file_uri": message.fileUri
                        }
                    }] : [])
                ]
            }
        })
        if (filePath && filePath.length > 0) {
            const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
            // Add inline_data part to the last message's parts array
            contents[contents.length - 1].parts.unshift({
                inline_data: {
                    mime_type: fileMimeTypeSubstitutionString,
                    data: fileDataSubstitutionString
                }
            });
        }
        let baseData = {
            "contents": contents,
            "tools": tools,
            "system_instruction": {
                "parts": [{ text: systemPrompt }]
            },
            "generationConfig": {
                "temperature": temperature,
            },
        };
        // print("Gemini API call payload:", JSON.stringify(baseData, null, 2));
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        // Gemini doesn't use Authorization header, key is in URL
        return "";
    }
    function parseResponseLine(line, message) {
        if (line.startsWith("[")) {
            buffer += line.slice(1).trim();
        } else if (line === "]") {
            buffer += line.slice(0, -1).trim();
            return parseBuffer(message);
        } else if (line.startsWith(",")) {
            return parseBuffer(message);
        } else {
            buffer += line.trim();
        }
        return {};
    }
    function parseBuffer(message) {
        // console.log("[Ai] Gemini buffer: ", buffer);
        let finished = false;
        try {
            if (buffer.length === 0) return {};
            const dataJson = JSON.parse(buffer);
            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error ${dataJson.error.code}**: ${dataJson.error.message}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }
            // No candidates?
            if (!dataJson.candidates) return {};

            // Finished?
            if (dataJson.candidates[0]?.finishReason) {
                finished = true;
            }

            // Function call handling
            if (dataJson.candidates[0]?.content?.parts[0]?.functionCall) {
                const functionCall = dataJson.candidates[0]?.content?.parts[0]?.functionCall;
                message.functionName = functionCall.name;
                message.functionCall = functionCall.name;
                const newContent = `\n\n[[ Function: ${functionCall.name}(${JSON.stringify(functionCall.args, null, 2)}) ]]\n`
                message.rawContent += newContent;
                message.content += newContent;
                return { functionCall: { name: functionCall.name, args: functionCall.args }, finished: finished };
            }
            // Normal text response
            const responseContent = dataJson.candidates[0]?.content?.parts[0]?.text
            message.rawContent += responseContent;
            message.content += responseContent;

            // Handle annotations and metadata
            const annotationSources = dataJson.candidates[0]?.groundingMetadata?.groundingChunks?.map(chunk => {
                return {
                    "type": "url_citation",
                    "text": chunk?.web?.title,
                    "url": chunk?.web?.uri,
                }
            }) ?? [];
            const annotations = dataJson.candidates[0]?.groundingMetadata?.groundingSupports?.map(citation => {
                return {
                    "type": "url_citation",
                    "start_index": citation.segment?.startIndex,
                    "end_index": citation.segment?.endIndex,
                    "text": citation?.segment.text,
                    "url": annotationSources[citation.groundingChunkIndices[0]]?.url,
                    "sources": citation.groundingChunkIndices
                }
            });
            message.annotationSources = annotationSources;
            message.annotations = annotations;
            message.searchQueries = dataJson.candidates[0]?.groundingMetadata?.webSearchQueries ?? [];
            // Usage metadata
            if (dataJson.usageMetadata) {
                return {
                    tokenUsage: {
                        input: dataJson.usageMetadata.promptTokenCount ?? -1,
                        output: dataJson.usageMetadata.candidatesTokenCount ?? -1,
                        total: dataJson.usageMetadata.totalTokenCount ?? -1
                    },
                    finished: finished
                };
            }

        } catch (e) {
            console.log("[AI] Gemini: Could not parse buffer: ", e);
            message.rawContent += buffer;
            message.content += buffer;
        } finally {
            buffer = "";
        }
        return { finished: finished };
    }
    function onRequestFinished(message) {
        return parseBuffer(message);
    }

    function reset() {
        buffer = "";
    }
    function buildScriptFileSetup(filePath) {
        const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
        let content = ""
        // print("file path:", filePath)
        // print("trimmed file path:", trimmedFilePath)
        // print("escaped file path:", CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath))
        content += `IMAGE_PATH='${CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath)}'\n`;
        content += `${fileMimeTypeVarName}=$(file -b --mime-type "$IMAGE_PATH")\n`;
        content += `${fileDataVarName}=$(base64 -w 0 "$IMAGE_PATH")\n`;
        return content
    }
    function finalizeScriptContent(scriptContent: string): string {
        return scriptContent.replace(fileMimeTypeSubstitutionString, `'"\$${fileMimeTypeVarName}"'`)
        .replace(fileDataSubstitutionString, `'"\$${fileDataVarName}"'`);
    }
}
