#!/bin/bash

output_file="./ebooks.json"
response=""

load_more_count=12
while true; do
  response=$(
    curl --silent \
         --data-urlencode "searchWord=" \
         --data-urlencode "TypeList=all" \
         --data-urlencode "load-more-count=$load_more_count" \
         --request POST "https://www.syncfusion.com/ebooks"
  )

  is_load_more_button=$(
    echo "$response" \
    | xmllint --html -xpath 'count(//button[@id="load-more"])' -
  )

  if [ "$is_load_more_button" -eq 0 ]; then
    break
  fi

  load_more_count=$(( $load_more_count + 12 ))
  echo "load_more_count=$load_more_count"
done

count=$(
  echo "$response" \
  | xmllint --html -xpath 'count(//div[contains(@class, "list-details")])' -
)
echo "count=$count"

if [ ! -f "$output_file" ]; then
    echo '{ "ebooks": [] }' > "$output_file"
fi

for (( c=count; c>=1; c-- )); do
  img_src=$(
    echo "$response" \
    | xmllint --html -xpath 'string((//div[contains(@class, "list-details")]/div[@class="withoutpad"])['$c']//img/attribute::src)' -
  )

  a_href=$(
    echo "$response" \
    | xmllint --html -xpath 'string((//div[contains(@class, "list-details")]/div[@class="withoutleftpad"])['$c']//a/attribute::href)' -
  )

  a_text=$(
    echo "$response" \
    | xmllint --html -xpath 'string((//div[contains(@class, "list-details")]/div[@class="withoutleftpad"])['$c']//a/child::text())' -
  )

  title="$(echo -e "${a_text}" | tr -d '\r\n' | sed -e 's/\xc2\xa0/ /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "title=$title"

  url="https://www.syncfusion.com$a_href"
  img="https:$img_src"

  is_book_saved=$(jq '[.ebooks[] | select(.url == "'"$url"'")] | length' "$output_file")
  if [ "$is_book_saved" -eq 0 ]; then
    #jq '.ebooks += [{"title": "'"$title"'", "url": "'"$url"'", "img": "'"$img"'"}]' "$output_file" \
    jq '.ebooks |= [{"title": "'"$title"'", "url": "'"$url"'", "img": "'"$img"'"}] + .' "$output_file" \
    | sponge "$output_file"
  fi

done

jq '.ebooks | length' "$output_file"

now=$(date +"%Y/%m/%d %H:%M:%S")
git add "$output_file"
echo "git commit -S -m \"Список книг в JSON-формате на $now.\""
