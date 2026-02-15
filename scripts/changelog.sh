#!/bin/bash
set -e

REPO_URL="https://github.com/jkuri/Reframed"
OUTPUT="CHANGELOG.md"
HEADER="# Changelog"

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -o, --output FILE    Output file (default: CHANGELOG.md)"
  echo "  -u, --url URL        Repository URL (default: ${REPO_URL})"
  echo "  -t, --tag TAG        Generate only for a specific tag"
  echo "  --unreleased         Include unreleased changes since last tag"
  echo "  --stdout             Print to stdout instead of file"
  echo "  -h, --help           Show this help"
  exit 0
}

SPECIFIC_TAG=""
UNRELEASED=false
TO_STDOUT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -u|--url) REPO_URL="$2"; shift 2 ;;
    -t|--tag) SPECIFIC_TAG="$2"; shift 2 ;;
    --unreleased) UNRELEASED=true; shift ;;
    --stdout) TO_STDOUT=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

type_label() {
  case "$1" in
    feat)     echo "Features" ;;
    fix)      echo "Bug Fixes" ;;
    perf)     echo "Performance" ;;
    refactor) echo "Refactoring" ;;
    style)    echo "Styling" ;;
    docs)     echo "Documentation" ;;
    chore)    echo "Chores" ;;
    build)    echo "Build" ;;
    ci)       echo "CI" ;;
    test)     echo "Tests" ;;
    revert)   echo "Reverts" ;;
    *)        echo "" ;;
  esac
}

TYPE_ORDER="feat fix perf refactor style docs chore build ci test revert"

get_tags() {
  git tag -l 'v*' --sort=-v:refname
}

get_tag_date() {
  git log -1 --format='%ai' "$1" 2>/dev/null | cut -d' ' -f1
}

get_commits() {
  local from="$1"
  local to="$2"

  if [ -n "$from" ]; then
    git log "${from}..${to}" --pretty=format:"%H|%s" --no-merges
  else
    git log "${to}" --pretty=format:"%H|%s" --no-merges
  fi
}

format_section() {
  local tag="$1"
  local prev_tag="$2"
  local date="$3"
  local commits_raw="$4"
  local buf=""
  local tmpdir
  tmpdir=$(mktemp -d)

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local hash="${line%%|*}"
    local subject="${line#*|}"
    local short_hash="${hash:0:7}"

    local type="" scope="" message=""
    local release_re='^chore\(release\)'
    [[ "$subject" =~ $release_re ]] && continue
    local scoped_re='^([a-z]+)\(([^)]+)\)!?:[[:space:]](.+)$'
    local plain_re='^([a-z]+)!?:[[:space:]](.+)$'
    if [[ "$subject" =~ $scoped_re ]]; then
      type="${BASH_REMATCH[1]}"
      scope="${BASH_REMATCH[2]}"
      message="${BASH_REMATCH[3]}"
    elif [[ "$subject" =~ $plain_re ]]; then
      type="${BASH_REMATCH[1]}"
      message="${BASH_REMATCH[2]}"
    else
      continue
    fi

    local label
    label=$(type_label "$type")
    [ -z "$label" ] && continue

    local entry
    if [ -n "$scope" ]; then
      entry="- **${scope}:** ${message} ([${short_hash}](${REPO_URL}/commit/${hash}))"
    else
      entry="- ${message} ([${short_hash}](${REPO_URL}/commit/${hash}))"
    fi

    echo "$entry" >> "${tmpdir}/${type}"
  done <<< "$commits_raw"

  if [ -n "$prev_tag" ]; then
    buf+="## [${tag}](${REPO_URL}/compare/${prev_tag}...${tag}) (${date})"$'\n'
  elif [ "$tag" = "Unreleased" ]; then
    buf+="## Unreleased"$'\n'
  else
    buf+="## [${tag}](${REPO_URL}/releases/tag/${tag}) (${date})"$'\n'
  fi

  local has_content=false
  for type in $TYPE_ORDER; do
    if [ -f "${tmpdir}/${type}" ]; then
      has_content=true
      local label
      label=$(type_label "$type")
      buf+=$'\n'"### ${label}"$'\n'$'\n'
      buf+="$(cat "${tmpdir}/${type}")"$'\n'
    fi
  done

  rm -rf "$tmpdir"

  if $has_content; then
    echo "$buf"
  fi
}

generate() {
  local changelog="${HEADER}"$'\n'
  local tags_raw
  tags_raw=$(get_tags)

  if [ -z "$tags_raw" ]; then
    echo "No tags found." >&2
    exit 1
  fi

  local tags=()
  while IFS= read -r t; do
    tags+=("$t")
  done <<< "$tags_raw"

  if $UNRELEASED; then
    local latest="${tags[0]}"
    local unreleased_commits
    unreleased_commits=$(get_commits "$latest" "HEAD")
    if [ -n "$unreleased_commits" ]; then
      local section
      section=$(format_section "Unreleased" "" "" "$unreleased_commits")
      if [ -n "$section" ]; then
        changelog+=$'\n'"${section}"$'\n'
      fi
    fi
  fi

  if [ -n "$SPECIFIC_TAG" ]; then
    local prev=""
    for i in "${!tags[@]}"; do
      if [ "${tags[$i]}" = "$SPECIFIC_TAG" ]; then
        local next=$((i + 1))
        if [ $next -lt ${#tags[@]} ]; then
          prev="${tags[$next]}"
        fi
        break
      fi
    done
    local date
    date=$(get_tag_date "$SPECIFIC_TAG")
    local commits
    commits=$(get_commits "$prev" "$SPECIFIC_TAG")
    local section
    section=$(format_section "$SPECIFIC_TAG" "$prev" "$date" "$commits")
    if [ -n "$section" ]; then
      changelog+=$'\n'"${section}"$'\n'
    fi
  else
    for i in "${!tags[@]}"; do
      local tag="${tags[$i]}"
      local prev=""
      local next=$((i + 1))
      if [ $next -lt ${#tags[@]} ]; then
        prev="${tags[$next]}"
      fi
      local date
      date=$(get_tag_date "$tag")
      local commits
      commits=$(get_commits "$prev" "$tag")
      local section
      section=$(format_section "$tag" "$prev" "$date" "$commits")
      if [ -n "$section" ]; then
        changelog+=$'\n'"${section}"$'\n'
      fi
    done
  fi

  if $TO_STDOUT; then
    echo "$changelog"
  else
    echo "$changelog" > "$OUTPUT"
    echo "Generated ${OUTPUT}"
  fi
}

generate
