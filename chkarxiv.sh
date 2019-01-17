#!/bin/bash

#HTTP_UA='Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36'
HTTP_UA='w3m/0.5.3'

dstamp=.chkarxiv/stamp
dcache=.chkarxiv/cache
dhtmlc=.chkarxiv/html

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

mkd "$dstamp"
mkd "$dcache"
mkd "$dhtmlc"

#-------------------------------------------------------------------------------

## @fn cmd:update-arxiv arxivNumber...
##   @var[in] dcache
##   @var[in] HTTP_UA
function cmd:update-arxiv {
  local arxiv
  for arxiv; do
    if [[ $arxiv == ?*. ]]; then
      arxiv=${arxiv%.}
      local -a list=($dcache/${arxiv%.}/?*.?*.htm)
      list=(${list[@]##*/})
      list=(${list[@]%.htm})
      cmd:update-arxiv "${list[@]}"
    else
      cmd:update-arxiv/core "$arxiv"
    fi
  done
}

function cmd:update-arxiv/core {
  local arxiv="$1"
  if [[ $arxiv != ?*.?* ]]; then
    echo "(arxiv=$arxiv): invalid format!" >&2
    return 1
  fi

  local fhtm="$dcache/${arxiv%%.*}/$arxiv.htm"
  [[ -d ${fhtm%/*} ]] || mkdir -p "${fhtm%/*}"
  if test ! -s "$fhtm"; then
    wget --no-verbose --user-agent="$HTTP_UA" --referer="http://arxiv.org/list/nucl-th/recent" "http://arxiv.org/abs/$arxiv" -O "$fhtm"
    sleep 5
  fi

  mkd "$dhtmlc/${arxiv%%.*}"
  local fhtm_ind=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.ind.htm
  local fhtm_sum=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.sum.htm
  if [[ ! -s $fhtm_ind || ! -s $fhtm_sum ]]; then
    awk '
      BEGIN {
        arXivId = "'$arxiv'";
        title_head1 = "<a href=\"http://arxiv.org/pdf/" arXivId ".pdf\"><img src=\"/agh/icons/file-pdf.png\" alt=\"pdf\" /></a>";
        title_head2 = "<a href=\"http://arxiv.org/abs/" arXivId "\">arXiv:" arXivId "</a>";
        title_head = title_head1 " " title_head2 ": ";
      }

      function print_content() {
        gsub(/href="\//, "href=\"http://arxiv.org/");

        # title
        gsub(/^<h1 class="title( mathjax)?"><span class="descriptor">Title:<\/span>/, "<h2 class=\"title\" id=\"arxiv." arXivId "\">" title_head);
        gsub(/<\/h1>/, "</h2>");

        # author list
        gsub(/id="long-author-list"/, "class=\"long-author-list\"");

        # abstract
        gsub(/\yblockquote\y/, "p");
        print;
      }

      /href="javascript:toggleAuthorList/ { next; }
      /^[[:space:]]*<h1 class="title( mathjax)?">/ {
        swch = 1;

        # read title1
        swch_title = 1;
        _text = $0;
        sub(/^.*Title:<\/span>/, "", _text);
        title = _text;

        print_content();
        next;
      }
      /^[[:space:]]*<\/blockquote>/ {
        swch=0; print_content(); next;
      }
      swch == 1 {
        # read title
        if (swch_title) {
          _text = $0;
          if (_text~/<\/h1>/) {
            sub(/<\/h1>.*$/, "", _text);
            swch_title = 0;
          }
          title = title _text;
        }

        print_content(); next;
      }

      /^<td class="tablecell subjects">/ {
        gsub(/^<td class="tablecell subjects">/, "<p class=\"subjects\">");
        gsub(/<\/td>/, "</p>");

        gsub(/Nuclear Theory \(nucl-th\)/, "<span class=\"subject-nucl-th\">nucl-th</span>");
        gsub(/Nuclear Experiment \(nucl-ex\)/, "<span class=\"subject-nucl-ex\">nucl-ex</span>");
        gsub(/High Energy Physics - Experiment \(hep-ex\)/, "<span class=\"subject-hep-ex\">hep-ex</span>");
        gsub(/High Energy Physics - Phenomenology \(hep-ph\)/, "<span class=\"subject-hep-ph\">hep-ph</span>");
        print;
      }

      END {
        print "<li>" title_head "<a class=\"internal article-index-title\" href=\"#arxiv." arXivId "\">" title "</a></li>" > "'"$fhtm_ind"'"
      }
    ' "$fhtm" > "$fhtm_sum"
  fi
}

#-------------------------------------------------------------------------------

## @fn cmd:update-arxiv arxivNumber...
##   @var[in] dcache
##   @var[in] HTTP_UA
function cmd:get-content-html {
  local arxiv
  for arxiv; do
    if [[ $arxiv == ?*. ]]; then
      arxiv=${arxiv%.}
      local -a list=($(ls -1r $dcache/${arxiv%.}/?*.?*.htm))
      list=(${list[@]##*/})
      list=(${list[@]%.htm})
      cmd:get-content-html "${list[@]}"
    else
      cmd:get-content-html/core "$arxiv"
    fi
  done
}

function cmd:get-content-html/core {
  local arxiv="$1"
  if [[ $arxiv != ?*.?* ]]; then
    echo "(arxiv=$arxiv): invalid format!" >&2
    return 1
  fi

  local fhtm_sum=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.sum.htm
  [[ -s $fhtm_sum ]] || cmd:update-arxiv/core "$arxiv"
  cat "$fhtm_sum"
}

#-------------------------------------------------------------------------------

function create_list_html {
  local outputFile=
  while [[ $1 == -* ]]; do
    local arg="$1"
    shift
    case "$arg" in
    (-o)  outputFile="$1"; shift ;;
    (-o*) outputFile="${arg:2}"  ;;
    (*)
      echo "create_list_html: unexpected option '$arg'!" >&2
      return 1 ;;
    esac
  done

  local date="$1"
  local flst="$2" 
  http_referer="http://arxiv.org/list/$cat/recent"

  local -a sum_list
  local -a ind_list

  local arxiv
  while read arxiv; do
    if [[ ! $arxiv ]]; then
      continue
    elif [[ $arxiv =~ ^http://arxiv.org/abs/([0-9.]+) ]]; then
      arxiv="${BASH_REMATCH[1]}"
    fi

    cmd:update-arxiv "$arxiv"

    local fhtm_ind=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.ind.htm
    local fhtm_sum=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.sum.htm
    sum_list+=($fhtm_sum)
    ind_list+=($fhtm_ind)
  done < "$flst"

  local ftmp=.chkarxiv/arxiv.tmp.htm
  local ftmp_index=.chkarxiv/index.tmp.htm
  cat "${sum_list[@]}" > "$ftmp"
  cat "${ind_list[@]}" > "$ftmp_index"

  : ${outputFile:=arxiv$date.htm}

  export CHK_ARXIV_DATE="$date"
  mwg_pp.awk chkarxiv.pp.htm > "$outputFile"
}

#
#------------------------------------------------------------------------------
# arxiv id list

declare -a aid_list_dates
function aid_list.add {
  local date="$1"
  local arxiv="$2"
  local fdate1="$dstamp/${arxiv%%.*}/$arxiv"
  test -s "$fdate1" && return
  mkd "${fdate1%/*}"
  echo -n "$date" > "$fdate1"

  local fdate="$dstamp/$date.txt"
  if test ! -f "$fdate.part"; then
    aid_list_dates+=("$date")
    if test -f "$fdate"; then
      cp "$fdate" "$fdate.part"
    else
      touch "$fdate.part"
    fi
  fi

  echo "$arxiv" >> "$fdate.part"
}
function aid_list.canonicalize {
  local date="$1"
  local fdate="$dstamp/$date.txt"
  if test -f "$fdate.part"; then
    sort -u "$fdate.part" > "$fdate"
    rm -f "$fdate.part"
  fi
}
function aid_list.generate_html {
  if test $# -gt 0; then
    local date="$1"
    local fdate="$dstamp/$date.txt"
    aid_list.canonicalize "$date"
    create_list_html "$date" "$fdate"
  else
    for date in "${aid_list_dates[@]}"; do
      aid_list.generate_html "$date"
    done
  fi
}

function arxiv_list.regenerateListFromStamp {
  local date="$1"
  local month1="${date::6}"
  local month2="$((month1%100==12?(month1%100+101):(month1+1)))"

  local fdate="$dstamp/$date.txt"
  cp "$fdate" "$fdate.part"

  local fdate1
  for fdate1 in "$dstamp/${month1:2}"/* "$dstamp/${month2:2}"/*; do
    if [[ $(< "$fdate1") == "$date" ]]; then
      echo "${fdate1##*/}" >> "$fdate.part"
    fi
  done

  aid_list.canonicalize "$date"
}

#------------------------------------------------------------------------------

function arxiv_check_recent {
  local categories='nucl-th nucl-ex hep-ph hep-ex'
  for cat in $categories; do
    local http_ua="$HTTP_UA"
    local http_referer="http://arxiv.org/list/$cat/recent"
    local wget_output=".chkarxiv/$cat.tmp"
    #if test ! -s "$wget_output"; then
    if true; then
      wget --no-verbose --user-agent="$http_ua" --referer="$http_referer" "http://arxiv.org/list/$cat/pastweek?show=1000" -O "$wget_output"
      sleep 5
    fi
    egrep '^<h3>|class="list-identifier"' "$wget_output" | awk '
      /^<h3>/{
        gsub(/<h3>([[:alpha:]]+\, *)?|<\/h3>/,"");
        gsub(/ /,"-");
        date=$0;
        next;
      }
  
      {
        match($0,/arXiv:([0-9]+\.[0-9]+)/,m);
        print date,m[1]
      }
    '
  done | (

    function parse_date {
      IFS=- eval 'local date=($1)'

      case "${date[1]}" in
      Jan) date[1]=01 ;;
      Feb) date[1]=02 ;;
      Mar) date[1]=03 ;;
      Apr) date[1]=04 ;;
      May) date[1]=05 ;;
      Jun) date[1]=06 ;;
      Jul) date[1]=07 ;;
      Aug) date[1]=08 ;;
      Sep) date[1]=09 ;;
      Oct) date[1]=10 ;;
      Nov) date[1]=11 ;;
      Dec) date[1]=12 ;;
      esac

      if test ${#date[0]} -eq 1; then
        date[0]="0${date[0]}"
      fi

      echo -n "${date[2]}${date[1]}${date[0]}"
    }

    local line
    while read line; do
      local field=($line)
      local date="$(parse_date "${field[0]}")"
      local arxiv="${field[1]}"
      # echo dbg: aid_list.add "$date" "$arxiv"
      aid_list.add "$date" "$arxiv"
    done

    aid_list.generate_html
  )
}

function fdate_update1 {
  create_list_html "$1" "$dstamp/$1.txt"
}

# aid_list.generate_html 20140120
# aid_list.generate_html 20140121
# aid_list.generate_html 20140122

#------------------------------------------------------------------------------

function generate_html_ArticleListSlide {
  awk '
    /class="title"/{fT=1;}
    fT==1{sub(/arXiv:/,"");print;}
    /<\/h2>/{fT=0;}

    /class="authors"/{fA=1;}
    fA==1{
      gsub(/<span class="descriptor">Authors:<\/span>|<a href="[^"]+">|<\/a>/,"");
      print;
    }
    /<\/div>/{fA=0}
  ' "$1"
}

# Usage
#   1$ emacs .chkarxiv/stamp/jc20130101.txt
#   2$ aid_list.generate_html jc20130101
#   3$ generate_html_ArticleListSlide arxivjc20130101.htm > a.htm
#

# aid_list.generate_html jc20131025
# aid_list.generate_html jc20131213
# generate_html_ArticleListSlide arxivjc20131213.htm > a.htm

# aid_list.generate_html jc20140710
# generate_html_ArticleListSlide arxivjc20140710.htm > a.htm

#------------------------------------------------------------------------------

# fdate_update1 20130916
# fdate_update1 20130917
# fdate_update1 20130918
# fdate_update1 20130919
# fdate_update1 20130920

#fdate_update1 20131016
#fdate_update1 20131017
#fdate_update1 20131018
#fdate_update1 20131021

# source backup/chkarxiv.20130923.src
# source backup/chkarxiv.20131016.src
# source backup/chkarxiv.20130930.src

function cmd:recent {
  arxiv_check_recent
}

function cmd:list {
  create_list_html -o "$2" "${1%.lst}" "$1"
}

# その月を全て生成する場合
# cat .chkarxiv/stamp/201706??.txt > .chkarxiv/201706.txt
# create_list_html -o fjc201706.htm 201706 .chkarxiv/201706.txt
#create_list_html -o fjc201705.htm 201705 .chkarxiv/201705.txt

if declare -f cmd:"$1" &>/dev/null; then
  cmd:"$@"
else
  echo 'unknown process type!' 2>&1
  cmdlist=$(declare -F | sed -n 's/declare -f cmd://p')
  echo command_list = $cmdlist
  exit 1
fi
