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

set -g GAME_EXCLUDE_NAMES "applications" "helper" "ii-original-dots-backup" "portproton" "music" "video" "undefined.bak"

set -g GAME_PATHS
set -g GAME_NAMES

function __build_game_index --description 'Сканирует GAME_DIRS и заполняет GAME_PATHS / GAME_NAMES'
    # Очистить
    set -g GAME_PATHS
    set -g GAME_NAMES

    for entry in $GAME_DIRS
        set -l path $entry
        set -l base (basename -- "$path")
        set -l lower_base (string lower -- $base)

        set -l skip_flag 0
        for ex in $GAME_EXCLUDE_NAMES
            if test (string match -q "*$ex*" -- $lower_base)
                set skip_flag 1
                break
            end
        end
        if test $skip_flag -eq 1
            continue
        end

        if test -f "$path"
            set -g GAME_PATHS $GAME_PATHS "$path"
            set -g GAME_NAMES $GAME_NAMES "$base"
            continue
        end

        if test -d "$path"
            set -l launcher ""
            for cand in "$path"/game.sh "$path"/launch.sh "$path"/run.sh "$path"/start.sh "$path"/renpy.sh "$path"/(basename "$path").sh
                if test -f "$cand" -a -x "$cand"
                    set launcher "$cand"
                    break
                end
            end
            if test -z "$launcher"
                for f in "$path"/*.sh
                    if test -f "$f" -a -x "$f"
                        set launcher "$f"
                        break
                    end
                end
            end
            if test -z "$launcher"
                for f in "$path"/*.x86_64
                    if test -f "$f" -a -x "$f"
                        set launcher "$f"
                        break
                    end
                end
            end
            if test -z "$launcher"
                for f in "$path"/*.AppImage
                    if test -f "$f" -a -x "$f"
                        set launcher "$f"
                        break
                    end
                end
            end
            if test -n "$launcher"
                set -g GAME_PATHS $GAME_PATHS "$launcher"
                set -g GAME_NAMES $GAME_NAMES "$base"
            else
                # нет явного лаунчера — добавим директорию для информативности
                set -g GAME_PATHS $GAME_PATHS "$path"
                set -g GAME_NAMES $GAME_NAMES "$base"
            end
            continue
        end

        set -g GAME_PATHS $GAME_PATHS "$path"
        set -g GAME_NAMES $GAME_NAMES "$base"
    end

    complete -c game -e 2>/dev/null

    set -l total (count $GAME_NAMES)
    for i in (seq 1 $total)
        complete -c game -a (string escape $i) -d "$GAME_NAMES[$i]" -f
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
        set -l launcher ""
        for cand in "$target"/game.sh "$target"/launch.sh "$target"/run.sh "$target"/start.sh "$target"/renpy.sh "$target"/(basename "$target").sh
            if test -f "$cand" -a -x "$cand"
                set launcher "$cand"
                break
            end
        end
        if test -z "$launcher"
            for f in "$target"/*.sh
                if test -f "$f" -a -x "$f"
                    set launcher "$f"
                    break
                end
            end
        end

        if test -n "$launcher"
            set target $launcher
        else
            echo "Не найден исполняемый файл в папке: $target"
            return 1
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
