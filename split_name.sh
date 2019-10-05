for i in $(seq -f "%02g" 11); do tg=$(ls -1 *_${i}_* | head -1 | sed 's/.*_[0-9][0-9]_\([a-z].*\)_[0-9][0-9][0-9][0-9]_.*$/\1/g'); mkdir -p mitch_rapp/$tg; mv *_${i}_*/* mitch_rapp/$tg; done
find -name '*.mp3' -exec rm '{}' \;
find -name '*.converted'  -exec rm '{}' \;
for i in $(find -name '*.split'); do mv $i ${i/.split/}; done
