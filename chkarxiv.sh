#!/bin/bash

#HTTP_UA='Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36'
HTTP_UA='w3m/0.5.3'

dstamp=.chkarxiv/stamp
dcache=.chkarxiv/cache
dhtmlc=.chkarxiv/html

fname_log=chkarxiv.log

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

mkd "$dstamp"
mkd "$dcache"
mkd "$dhtmlc"

function util/wget {
  wget --no-check-certificate --no-verbose --user-agent="$HTTP_UA" "$@"
}

#-------------------------------------------------------------------------------

## 関数 cmd:update-arxiv arxivNumber...
##   @var[in] dcache
##   @var[in] HTTP_UA
function cmd:update-arxiv {
  local arxiv opts=
  for arxiv; do
    if [[ $arxiv == +o* ]]; then
      opts=$opts:${arxiv:2}
    elif [[ $arxiv == ?*. ]]; then
      arxiv=${arxiv%.}
      local -a list=($dcache/${arxiv%.}/?*.?*.htm)
      list=(${list[@]##*/})
      list=(${list[@]%.htm})
      cmd:update-arxiv "${list[@]}"
    else
      cmd:update-arxiv/.check-arxiv-number "$arxiv" "$opts" &&
        cmd:update-arxiv/.download-abs-page "$arxiv" "$opts" &&
        cmd:update-arxiv/.extract-title-and-abstract "$arxiv" "$opts"
    fi
  done
}

## 関数 cmd:update-arxiv/.check-arxiv-number
##   @param[in] arxiv
##   arxiv が 1810.00001 の形式を持っているかどうかを確認します。
function cmd:update-arxiv/.check-arxiv-number {
  local arxiv=$1
  if [[ $arxiv != ?*.?* ]]; then
    echo "(arxiv=$arxiv): invalid format!" >&2
    return 1
  fi
  return 0
}

## 関数 cmd:update-arxiv/.extract-title-and-abstract arxiv
##   @param[in] arxiv
##     1810.00001 の形式の番号を指定します。
##   .chkarxiv/cache/1810/1810.13394.htm にファイルを保存します。
function cmd:update-arxiv/.download-abs-page {
  local arxiv=$1
  local fhtm=$dcache/${arxiv%%.*}/$arxiv.htm
  mkd "${fhtm%/*}"
  [[ -s $fhtm ]] && return 0
  util/wget --referer="https://arxiv.org/list/nucl-th/recent" "https://arxiv.org/abs/$arxiv" -O "$fhtm"; local ret=$?
  if ((ext)); then
    echo "(arxiv=$arxiv): failed to download the abstract page." >&2
    echo "(arxiv=$arxiv): failed to download the abstract page." >> "$fname_log"
  fi
  sleep 5
  return "$?"
}

## 関数 cmd:update-arxiv/.extract-title-and-abstract arxiv [opts]
##   .chkarxiv/cache/1810/1810.13394.htm からタイトルと概要を抽出して
##   .chkarxiv/html/1810/1810.13394.{ind,sum}.htm に保存します。
##   @param[in] arxiv
##     1810.00001 の形式の番号を指定します。
##   @param[in] opts
##     regen キャッシュの有無に関わらず再生成する事を示します。
function cmd:update-arxiv/.extract-title-and-abstract {
  local arxiv=$1 opts=:$2:
  mkd "$dhtmlc/${arxiv%%.*}"
  local fhtm=$dcache/${arxiv%%.*}/$arxiv.htm
  local fhtm_ind=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.ind.htm
  local fhtm_sum=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.sum.htm
  [[ $opts != *:regen:* && -s $fhtm_ind && -s $fhtm_sum ]] && return 0

  awk '
    BEGIN {
      arXivId = "'$arxiv'";
      title_head1 = "<a href=\"https://arxiv.org/pdf/" arXivId ".pdf\"><img src=\"/agh/icons/file-pdf.png\" alt=\"pdf\" /></a>";
      title_head2 = "<a href=\"https://arxiv.org/abs/" arXivId "\">arXiv:" arXivId "</a>";
      title_head = title_head1 " " title_head2 ": ";
    }

    function print_content() {
      gsub(/href="\//, "href=\"https://arxiv.org/");

      # title
      gsub(/^[[:space:]]*<h1 class="title( mathjax)?"><span class="descriptor">Title:<\/span>/, "<h2 class=\"title\" id=\"arxiv." arXivId "\">" title_head);
      gsub(/<\/h1>/, "</h2>");

      # author list
      gsub(/id="long-author-list"/, "class=\"long-author-list\"");

      # abstract
      gsub(/\yblockquote\y/, "p");
      print;
    }

    function title_initialize(line) {
      swch_title = 1;
      title = "";
      sub(/^.*Title:<\/span>/, "", line);
      title_check_and_append(line);
    }
    function title_check_and_append(line) {
      if (!swch_title) return;
      if (line ~ /<\/h1>/) {
        sub(/<\/h1>.*$/, "", line);
        swch_title = 0;
      }
      title = title line;
    }


    /^[[:space:]]*<h1 class="title( mathjax)?">/ {
      mode = "content";

      title_initialize($0);
      print_content();
      next;
    }
    mode == "content" {
      if (/\yhref="javascript:toggleAuthorList/) next;
      if (/\yclass="mobile-submission-download"/) next;
      if (/^[[:space:]]*$/) next;

      if (/^[[:space:]]*<\/blockquote>/) {
        mode = "";
        print_content();
        next;
      }

      title_check_and_append($0);
      print_content();
      next;
    }

    /^[[:space:]]*<td class="tablecell subjects">/ {
      gsub(/^[[:space:]]*<td class="tablecell subjects">/, "<p class=\"subjects\">");
      mode = "subjects";
      # FALL-THROUGH
    }
    mode == "subjects" {
      gsub(/^[[:space:]]+/, "");
      gsub(/Nuclear Theory \(nucl-th\)/, "<span class=\"subject-nucl-th\">nucl-th</span>");
      gsub(/Nuclear Experiment \(nucl-ex\)/, "<span class=\"subject-nucl-ex\">nucl-ex</span>");
      gsub(/High Energy Physics - Experiment \(hep-ex\)/, "<span class=\"subject-hep-ex\">hep-ex</span>");
      gsub(/High Energy Physics - Phenomenology \(hep-ph\)/, "<span class=\"subject-hep-ph\">hep-ph</span>");
      if (gsub(/<\/td>/, "</p>") == 0) {
        printf("%s", $0);
      } else {
        mode = "";
        print;
      }
    }

    END {
      print "<li>" title_head "<a class=\"internal article-index-title\" href=\"#arxiv." arXivId "\">" title "</a></li>" > "'"$fhtm_ind"'"
    }
  ' "$fhtm" > "$fhtm_sum"
}

#-------------------------------------------------------------------------------

## @fn cmd:get-content-html arxivNumber...
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
  local arxiv=$1
  if [[ $arxiv != ?*.?* ]]; then
    echo "(arxiv=$arxiv): invalid format!" >&2
    return 1
  fi

  local fhtm_sum=$dhtmlc/${arxiv%%.*}/${arxiv#*.}.sum.htm
  [[ -s $fhtm_sum ]] || cmd:update-arxiv "$arxiv"
  cat "$fhtm_sum"
}

#-------------------------------------------------------------------------------

function create_list_html {
  local outputFile= opts=:
  while [[ $1 == [-+]* ]]; do
    local arg=$1
    shift
    case $arg in
    (-o)  outputFile=$1; shift ;;
    (-o*) outputFile=${arg:2}  ;;
    (+o*)  opts=$opts${arg:2}: ;;
    (*)
      echo "create_list_html: unexpected option '$arg'!" >&2
      return 1 ;;
    esac
  done

  local date=$1
  local flst=$2 
  http_referer=https://arxiv.org/list/$cat/recent

  local -a sum_list
  local -a ind_list

  local arxiv
  while read arxiv; do
    if [[ ! $arxiv ]]; then
      continue
    elif [[ $arxiv =~ ^https?://arxiv.org/abs/([0-9.]+) ]]; then
      arxiv="${BASH_REMATCH[1]}"
    fi

    cmd:update-arxiv +o"$opts" "$arxiv"

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

  export CHK_ARXIV_DATE=$date
  mwg_pp.awk chkarxiv.pp.htm > "$outputFile"
}

#
#------------------------------------------------------------------------------
# arxiv id list

aid_list_dates=()
function aid_list.add {
  local date=$1
  local arxiv=$2
  local fdate1=$dstamp/${arxiv%%.*}/$arxiv
  [[ -s $fdate1 ]] && return
  mkd "${fdate1%/*}"
  echo -n "$date" > "$fdate1"

  local fdate=$dstamp/$date.txt
  if [[ ! -f $fdate.part ]]; then
    aid_list_dates+=("$date")
    if [[ -f $fdate ]]; then
      cp "$fdate" "$fdate.part"
    else
      touch "$fdate.part"
    fi
  fi

  echo "$arxiv" >> "$fdate.part"
}
## 関数 aid_list.canonicalize date
##   @param[in] date
##
##   その月の記事一覧ファイルに .part ファイルがあれば、
##   そのファイルをソートして記事一覧ファイルを置き換えます。
##
function aid_list.canonicalize {
  local date=$1
  local fdate=$dstamp/$date.txt
  if [[ -f $fdate.part ]]; then
    sort -u "$fdate.part" > "$fdate"
    rm -f "$fdate.part"
  fi
}
## 関数 aid_list.generate_html [date [opts]]
##   @param[in,opt] date
##     HTMLを生成する対象の日付を指定します。
##     もしくは記事番号一覧ファイルを指定します。
##     省略した場合は aid_list_dates を使用します。
function aid_list.generate_html {
  if (($#)); then
    local date=$1 opts=:$2:
    local fdate=$dstamp/$date.txt
    if [[ ! -f $fdate && -s $date ]]; then
      # ファイル名を直接指定した時
      fdate=$date
      date=${date##*/}
      date=${date%%.*}
    fi
    aid_list.canonicalize "$date"
    create_list_html +o"$opts" "$date" "$fdate"
  else
    local date
    for date in "${aid_list_dates[@]}"; do
      aid_list.generate_html "$date"
    done
  fi
}

## 関数 arxiv_list.regenerateListFromStamp date
##   @param[in] date
##     "201810" 等の月を指定する文字列を渡します。
function arxiv_list.regenerateListFromStamp {
  local date=$1
  local month1=${date::6}
  local month2=$((month1%100==12?(month1%100+101):(month1+1)))

  local fdate=$dstamp/$date.txt
  cp "$fdate" "$fdate.part"

  local fdate1
  for fdate1 in "$dstamp/${month1:2}"/* "$dstamp/${month2:2}"/*; do
    if [[ $(< "$fdate1") == $date ]]; then
      echo "${fdate1##*/}" >> "$fdate.part"
    fi
  done

  aid_list.canonicalize "$date"
}

#------------------------------------------------------------------------------

function arxiv_check_recent {
  local categories='nucl-th nucl-ex hep-ph hep-ex'
  for cat in $categories; do
    local http_referer=https://arxiv.org/list/$cat/recent
    local wget_output=.chkarxiv/$cat.tmp
    #if test ! -s "$wget_output"; then
    if true; then
      util/wget --referer="$http_referer" "https://arxiv.org/list/$cat/pastweek?show=1000" -O "$wget_output"
      sleep 5
    fi
    grep -E '^<h3>|class="list-identifier"' "$wget_output" | awk '
      /^<h3>/{
        gsub(/<h3>([[:alpha:]]+, *)?|<\/h3>/,"");
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

      case ${date[1]} in
      (Jan) date[1]=01 ;;
      (Feb) date[1]=02 ;;
      (Mar) date[1]=03 ;;
      (Apr) date[1]=04 ;;
      (May) date[1]=05 ;;
      (Jun) date[1]=06 ;;
      (Jul) date[1]=07 ;;
      (Aug) date[1]=08 ;;
      (Sep) date[1]=09 ;;
      (Oct) date[1]=10 ;;
      (Nov) date[1]=11 ;;
      (Dec) date[1]=12 ;;
      esac

      if ((${#date[0]}==1)); then
        date[0]=0${date[0]}
      fi

      echo -n "${date[2]}${date[1]}${date[0]}"
    }

    local line
    while read line; do
      local field=($line)
      local date=$(parse_date "${field[0]}")
      local arxiv=${field[1]}
      # echo dbg: aid_list.add "$date" "$arxiv"
      aid_list.add "$date" "$arxiv"
    done

    aid_list.generate_html
  )
}

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

## 関数 cmd:regenerate date
##   指定した日付の HTML を再生成します。
##   @param[in] date
##     8桁の日付を指定します。? が含まれる場合には
##     一致する日付全てについて処理を行います。
function cmd:regenerate {
  local date=$1
  if local rex='^20[0-9]{6}$'; [[ $date =~ $rex ]]; then
    aid_list.generate_html "$date" regen
  elif ((${#date}==8)) && [[ ! ${date//[0-9?]} ]]; then
    local file
    for file in .chkarxiv/stamp/$date.txt; do
      echo aid_list.generate_html "$file"
      aid_list.generate_html "$file" regen
    done
  fi
}

#------------------------------------------------------------------------------

function cmd:recent {
  arxiv_check_recent
}

function cmd:list {
  create_list_html -o "$2" "${1%.lst}" "$1"
}


# aid_list.generate_html 20140120
# aid_list.generate_html 20140121
# aid_list.generate_html 20140122

# aid_list.generate_html jc20131025
# aid_list.generate_html jc20131213
# generate_html_ArticleListSlide arxivjc20131213.htm > a.htm

# aid_list.generate_html jc20140710
# generate_html_ArticleListSlide arxivjc20140710.htm > a.htm

# aid_list.generate_html 20130916
# aid_list.generate_html 20130917
# aid_list.generate_html 20130918
# aid_list.generate_html 20130919
# aid_list.generate_html 20130920

# aid_list.generate_html 20131016
# aid_list.generate_html 20131017
# aid_list.generate_html 20131018
# aid_list.generate_html 20131021

# source backup/chkarxiv.20130923.src
# source backup/chkarxiv.20131016.src
# source backup/chkarxiv.20130930.src

# その月を全て生成する場合
# cat .chkarxiv/stamp/201706??.txt > .chkarxiv/201706.txt
# create_list_html -o fjc201706.htm 201706 .chkarxiv/201706.txt
# create_list_html -o fjc201705.htm 201705 .chkarxiv/201705.txt

# 2019-01-17
#   arXiv の形式が変わっていて 201810 から正常に HTML を生成できていなかったので、
#   .chkarxiv/html/20{1810,1811,1812,1901} を削除した上で、
#   改めてHTMLを再生成する
function cmd:20190117-regenerate {
  local file
  for file in .chkarxiv/stamp/20{18{10..12},19??}??.txt; do
    echo aid_list.generate_html "$file"
    aid_list.generate_html "$file"
  done
}

#aid_list.generate_html 20190117
#aid_list.generate_html 20240301

#------------------------------------------------------------------------------

if declare -f cmd:"$1" &>/dev/null; then
  cmd:"$@"
else
  echo 'unknown process type!' 2>&1
  cmdlist=$(declare -F | sed -n 's/declare -f cmd://p')
  echo command_list = $cmdlist
  exit 1
fi
