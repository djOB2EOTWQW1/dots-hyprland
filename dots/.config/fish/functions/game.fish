#!/usr/bin/env fish
set -g GAME_DIRS \
    "$HOME/.NSFW/Games Linux/RenPy/AttackOnSurveyCorps" \
    "$HOME/.NSFW/Games Linux/RenPy/CosyCafe" \
    "$HOME/.NSFW/Games Linux/RenPy/CrimsonHigh" \
    "$HOME/.NSFW/Games Linux/RenPy/DeepVault" \
    "$HOME/.NSFW/Games Linux/RenPy/Doomination" \
    "$HOME/.NSFW/Games Linux/RenPy/ElectricSheep" \
    "$HOME/.NSFW/Games Linux/RenPy/FakeFather" \
    "$HOME/.NSFW/Games Linux/RenPy/FourElementsTrainer" \
    "$HOME/.NSFW/Games Linux/RenPy/FromTheSin" \
    "$HOME/.NSFW/Games Linux/RenPy/HappySummer" \
    "$HOME/.NSFW/Games Linux/RenPy/HaremHotel" \
    "$HOME/.NSFW/Games Linux/RenPy/HoneyKingdom" \
    "$HOME/.NSFW/Games Linux/RenPy/Hornycraft" \
    "$HOME/.NSFW/Games Linux/RenPy/LessonsInLove" \
    "$HOME/.NSFW/Games Linux/RenPy/LifesPayback" \
    "$HOME/.NSFW/Games Linux/RenPy/MagicalMishaps" \
    "$HOME/.NSFW/Games Linux/RenPy/MIST" \
    "$HOME/.NSFW/Games Linux/RenPy/NekoParadise" \
    "$HOME/.NSFW/Games Linux/RenPy/NorikasCase" \
    "$HOME/.NSFW/Games Linux/RenPy/PhotoHunt" \
    "$HOME/.NSFW/Games Linux/RenPy/ProjektPassion" \
    "$HOME/.NSFW/Games Linux/RenPy/RSSU" \
    "$HOME/.NSFW/Games Linux/RenPy/RickAndMorty" \
    "$HOME/.NSFW/Games Linux/RenPy/TabooStories" \
    "$HOME/.NSFW/Games Linux/RenPy/TakeOver" \
    "$HOME/.NSFW/Games Linux/RenPy/TakeisJourney" \
    "$HOME/.NSFW/Games Linux/RenPy/TheHeadmaster" \
    "$HOME/.NSFW/Games Linux/RenPy/TheShopkeeper" \
    "$HOME/.NSFW/Games Linux/RenPy/WelcomeToErosland" \
    "$HOME/.NSFW/Games Linux/RenPy/WitchHunter" \
    "$HOME/.NSFW/Games Linux/RenPy/WTS" \
    "$HOME/.NSFW/Games Linux/RenPy/YesIamAFurry" \
    "$HOME/.NSFW/Games Linux/RenPy/inquisitorTrainer" \
    "$HOME/.NSFW/Games Linux/Unity/IN HEAT" \
    "$HOME/.NSFW/Games Linux/Unity/MyDystopianRobotGirlfriend" \
    "$HOME/.NSFW/Games Linux/Unity/PonyWaifuSim" \
    "$HOME/.NSFW/Games Linux/Other/LonaRPG/usr/bin/LonaRPG_RUS_Launcher"

set -g GAME_NV_ENV \
    "__NV_PRIME_RENDER_OFFLOAD=1" \
    "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
    "__VK_LAYER_NV_optimus=NVIDIA_only"

set -g GAME_PATHS
set -g GAME_NAMES

function __find_launcher --argument-names dir --description 'Находит первый исполняемый файл (.sh / .x86_64 / .AppImage) с учетом правил'
    if test -f "$dir"
        echo "$dir"
        return 0
    end

    if not test -d "$dir"
        echo "$dir"
        return 1
    end

    set -l dir_base (basename -- "$dir" | string lower)

    for ext in .sh .x86_64 .AppImage
        set -l files
        for file in "$dir"/*$ext
            if test -f "$file" -a -x "$file"
                set files $files "$file"
            end
        end

        if test (count $files) -eq 0
            continue
        end

        if string match -q -- '*.AppImage' "$files[1]"
            # Для .AppImage игнорируем проверку, берем первый
            echo $files[1]
            return 0
        else
            # Для .sh и .x86_64
            if test (count $files) -eq 1
                # Если только один, берем его без проверки
                echo $files[1]
                return 0
            else
                # Если несколько, проверяем совпадение имени без учета регистра
                for file in $files
                    set -l file_base (basename -- "$file" | string replace --regex '\Q'$ext'\E$' '' | string lower)
                    if test "$file_base" = "$dir_base"
                        echo "$file"
                        return 0
                    end
                end
                # Если ни один не совпадает, продолжаем к следующему ext
            end
        end
    end

    echo "$dir"  # если ничего не нашли — возвращаем саму папку
    return 1
end

function __build_game_index --description 'Сканирует GAME_DIRS и заполняет GAME_PATHS / GAME_NAMES (только валидные)'
    set -g GAME_PATHS
    set -g GAME_NAMES

    for entry in $GAME_DIRS
        set -l launcher (__find_launcher "$entry")

        if test $status -ne 0
            # Пропускаем игру, если лаунчер не найден
            continue
        end

        # Дополнительная проверка существования и исполняемости
        if not test -e "$launcher" -a -x "$launcher"
            continue
        end

        set -l base (basename -- "$entry")
        set -g GAME_PATHS $GAME_PATHS "$launcher"
        set -g GAME_NAMES $GAME_NAMES "$base"
    end

    # Перестраиваем автодополнение
    complete -c game -e 2>/dev/null

    set -l total (count $GAME_NAMES)
    for i in (seq 1 $total)
        complete -c game -a "$i" -d "$GAME_NAMES[$i]" -f
    end
end

__build_game_index

function game --description 'game <номер> — запустить игру'
    if test (count $argv) -eq 0
        printf "%3s  %s\n" "№" "ИМЯ"
        printf "%3s  %s\n" "---" "---------------------------"
        for i in (seq 1 (count $GAME_NAMES))
            printf "%3s) %s\n" $i $GAME_NAMES[$i]
        end
        return 0
    end

    if test "$argv[1]" = "refresh"
        __build_game_index
        echo "Индекс игр обновлён."
        return 0
    end

    set -l idx $argv[1]
    if not string match -r '^[0-9]+$' -- $idx >/dev/null
        echo "Ошибка: первый аргумент должен быть номером. Использование: game <номер>"
        return 1
    end

    set -l total (count $GAME_PATHS)
    if test $idx -lt 1 -o $idx -gt $total
        echo "Ошибка: нет игры с номером $idx (всего $total)."
        return 1
    end

    set -l target $GAME_PATHS[$idx]
    set -l extra_args
    if test (count $argv) -gt 1
        set extra_args $argv[2..-1]
    end

    if test -d "$target"
        set -l launcher (__find_launcher "$target")
        if test "$launcher" = "$target"
            echo "Не найден исполняемый файл в папке: $target"
            return 1
        else
            set target "$launcher"
        end
    end

    if not test -e "$target"
        echo "Целевой файл не найден: $target"
        return 1
    end

    echo "Запускаю: $GAME_NAMES[$idx]"
    echo "Файл: $target"

    if test -x "$target"
        setsid env $GAME_NV_ENV "$target" $extra_args >/dev/null 2>&1 &
    else
        setsid env $GAME_NV_ENV sh "$target" $extra_args >/dev/null 2>&1 &
    end

    return 0
end
