#!/bin/bash

AntiforgeryFieldname="YOUR_VALUE"
cookie=".AspNetCore.Antiforgery.1ZV8OwHkBWo=YOUR_VALUE; .ASPXAUTH=YOUR_VALUE; _sid=YOUR_VALUE;"

output_file="./ebooks.json"
response=""

((load_more_count=2**16))
response=$(
  curl --silent \
       --header "cookie: $cookie" \
       --data-urlencode "search-word=" \
       --data-urlencode "ebook-type-list-multi=all" \
       --data-urlencode "AntiforgeryFieldname=$AntiforgeryFieldname" \
       --data-urlencode "list=All" \
       --data-urlencode "load-more-count=$load_more_count" \
       --request POST "https://www.syncfusion.com/succinctly-free-ebooks"
)

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

  url=$(echo "https://www.syncfusion.com/$a_href" | xargs)

  img="https:$img_src"

  is_book_saved=$(jq '[.ebooks[] | select(.url == "'"$url"'")] | length' "$output_file")
  if [ "$is_book_saved" -eq 0 ]; then
    echo "- [$title]($url)"

    #jq '.ebooks += [{"title": "'"$title"'", "url": "'"$url"'", "img": "'"$img"'"}]' "$output_file" \
    jq '.ebooks |= [{"title": "'"$title"'", "url": "'"$url"'", "img": "'"$img"'"}] + .' "$output_file" \
    | sponge "$output_file"
  fi

done

jq '.ebooks | length' "$output_file"

now=$(date +"%Y/%m/%d %H:%M:%S")
git add "$output_file"
echo "git commit -S -m \"Список книг в JSON-формате на $now.\""
