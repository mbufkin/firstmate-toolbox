#!/usr/bin/env bash
# firstmate-splash - cinematic ASCII opener for firstmate.
# Renders each frame into a framebuffer and emits it in ONE write, so water,
# boat, stars and title appear together with no tearing.
#
# Usage:
#   firstmate-splash            play ~9s then exit (for the launcher)
#   firstmate-splash --hold     hold on the final banner until a keypress
#   firstmate-splash --frames N play N frames then exit (debug)
set -euo pipefail

WIDTH=100
HEIGHT=30
HOLD=0
NFRAMES=-1
[[ "${1:-}" == "--hold" ]] && HOLD=1 && shift
[[ "${1:-}" == "--frames" ]] && { NFRAMES="$2"; shift 2; }

ESC=$'\x1b'

# ---- color code letters -> 256-color index --------------------------------
declare -A CL
CL[a]=17; CL[b]=18; CL[c]=19; CL[d]=20; CL[e]=21
CL[f]=44; CL[g]=45; CL[h]=24; CL[i]=23; CL[j]=22
CL[k]=229; CL[l]=231; CL[m]=137; CL[n]=226; CL[o]=39
CL[p]=221; CL[q]=220; CL[r]=214; CL[s]=215; CL[t]=179
CL[u]=178; CL[v]=180; CL[w]=87; CL[x]=250

# ---- per-row base color letters -------------------------------------------
LETTERS=(a b c d e)
SKYL=()
for ((r = 0; r < 14; r++)); do SKYL[$r]=${LETTERS[$((r / 3))]}; done
SEAL=(f g g f h i i j j e d d c b a a)

GOLDL=(p q r s t u v k)   # title shimmer palette

# ---- precomputed helpers ---------------------------------------------------
SPACES=$(printf '%100s' '')
declare -A CROW100
for letter in {a..z}; do
  CROW100[$letter]=$(printf '%100s' '' | tr ' ' "$letter")
done
declare -A CSEQL
for letter in "${!CL[@]}"; do
  CSEQL[$letter]="${ESC}[38;5;${CL[$letter]}m"
done

# ---- moon -----------------------------------------------------------------
MOON=(
  "   .::::::.    "
  " .::::::::::.  "
  ".:::::::.::::.."
  ".::::o::::::.o:"
  ".:::::o:::::.:."
  " .::::::::::.  "
  "   .::::::.    "
)

# ---- sloop (sail + hull) --------------------------------------------------
SAIL=(
  "        |            "
  "       / \\           "
  "      /   \\          "
  "     /     \\         "
  "    /       \\        "
  "   /         \\       "
  "  /___________\\      "
  "      |    |         "
)
HULL=(
  "  ___|____|____      "
  " /    |    |    \\     "
  "|  o  |  o |  o  \\    "
  "| o o  o    o  o o |  "
  "|__________________|  "
  " \\  |  |  |  |  |   /  "
)

# ---- big letters (7 rows each) --------------------------------------------
L_F=("FFFFFF" "F     " "FFFF  " "F     " "F     " "F     " "F     ")
L_I=("IIIIII" "  II  " "  II  " "  II  " "  II  " "  II  " "IIIIII")
L_R=("RRRRR " "R    R" "R    R" "RRRRR " "R  R  " "R   R " "R    R")
L_S=(" SSSSS" "S     " "S     " " SSSS " "     S" "     S" "SSSSS ")
L_T=("TTTTTT" "  TT  " "  TT  " "  TT  " "  TT  " "  TT  " "  TT  ")
L_M=("M     M" "MM   MM" "M M M M" "M  M  M" "M     M" "M     M" "M     M")
L_A=("  AA  " " A  A " "A    A" "AAAAAA" "A    A" "A    A" "A    A")
L_E=("EEEEEE" "E     " "E     " "EEEEE " "E     " "E     " "EEEEEE")

declare -A LET
LET[F]=L_F; LET[I]=L_I; LET[R]=L_R; LET[S]=L_S; LET[T]=L_T
LET[M]=L_M; LET[A]=L_A; LET[E]=L_E
WORD=(F I R S T M A T E)
WID=(6 6 6 6 6 7 6 6 6)

glyph_at() { # letter row -> prints glyph row string
  local -n g=${LET[$1]}
  printf '%s' "${g[$2]}"
}

TITLE=("" "" "" "" "" "" "")
for ((row = 0; row < 7; row++)); do
  str=""
  for ((li = 0; li < 9; li++)); do
    str+="$(glyph_at "${WORD[li]}" "$row")"
    if ((li < 8)); then str+=" "; fi
  done
  TITLE[row]="$str"
done
TITLEW=63
TITLEC=$(( (WIDTH - TITLEW) / 2 ))

TAG=". the dream sets sail ."
TAGC=$(( (WIDTH - ${#TAG}) / 2 ))
MSG="firstmate is coming online"
MSGC=$(( (WIDTH - ${#MSG}) / 2 ))

# ---- stars (deterministic) -------------------------------------------------
STARR=(); STARC=(); STARI=()
for ((i = 0; i < 54; i++)); do
  STARR[$i]=$(( i % 13 ))
  STARC[$i]=$(( (i * 37 + i % 13 * 53) % 78 ))
  STARI[$i]=$i
done

# ---- framebuffer -----------------------------------------------------------
screen=()
crow=()

# put_text r c text ltr  (spaces are transparent; contiguous runs placed in one op)
put_text() {
  local r=$1 c=$2 text=$3 ltr=$4 len=${#3}
  local i=0 j ch run pad
  while (( i < len )); do
    ch=${text:i:1}
    if [[ "$ch" == " " ]]; then
      i=$((i + 1))
      continue
    fi
    j=$((i + 1))
    while (( j < len )) && [[ "${text:j:1}" != " " ]]; do j=$((j + 1)); done
    run="${text:i:$((j - i))}"
    screen[r]="${screen[r]:0:$((c + i))}${run}${screen[r]:$((c + j))}"
    printf -v pad '%*s' "$((j - i))" ""
    crow[r]="${crow[r]:0:$((c + i))}${pad// /$ltr}${crow[r]:$((c + j))}"
    if [[ -n "${OVC[r]}" ]]; then
      local -a ea
      IFS=';' read -r -a ea <<<"${OVC[r]%;}"
      local e es el ee os oe pruned=""
      os=$((c + i)); oe=$((c + j))
      for e in "${ea[@]}"; do
        es=${e%%:*}; el=${e#*:}; el=${el%%:*}; ee=$((es + el))
        if ((ee <= os || es >= oe)); then pruned+="$e;"; fi
      done
      OVC[r]="$pruned"
    fi
    OVC[r]+="$((c + i)):$((j - i)):$ltr;"
    DIRTY[r]=1
    i=$j
  done
}

WAVE_B=()
_wb0="==~==~==~==~==~=="
_wb1="==~~==~~==~~==~~==~~"
_wb2="=      =      =     "
_wb3=".   .   .   .   .   "
WAVE_B[0]="$_wb0$_wb0$_wb0$_wb0$_wb0"
WAVE_B[1]="$_wb1$_wb1$_wb1$_wb1$_wb1"
WAVE_B[2]="$_wb2$_wb2$_wb2$_wb2$_wb2"
WAVE_B[3]="$_wb3$_wb3$_wb3$_wb3$_wb3"

wave_row() { # row offset -> sets WROW to an ascii wave (rotate precomputed period-20 wave)
  local r=$1 off=$2 base
  if ((r <= 15)); then base=${WAVE_B[0]}
  elif ((r <= 18)); then base=${WAVE_B[1]}
  elif ((r <= 22)); then base=${WAVE_B[2]}
  else base=${WAVE_B[3]}
  fi
  off=$((off % 20))
  WROW="${base:off}${base:0:off}"
}

# build_scene F show_msg   -> fills screen/crow
build_scene() {
  local F=$1 show_msg=$2 r s

  # base rows
  for ((r = 0; r < 14; r++)); do
    screen[r]="$SPACES"
    crow[r]="${CROW100[${SKYL[$r]}]}"
    DIRTY[r]=0
    OVC[r]=""
  done
  for ((r = 14; r < 30; r++)); do
    wave_row "$r" $(( F * (r % 3 + 1) ))
    screen[r]="$WROW"
    crow[r]="${CROW100[${SEAL[$((r - 14))]}]}"
    DIRTY[r]=0
    OVC[r]=""
  done

  # stars
  for ((si = 0; si < 54; si++)); do
    sr=${STARR[si]}; sc=${STARC[si]}
    if ((sc >= 82)); then continue; fi
    ch=""
    if ((si % 7 == 0)); then
      ((F / 6 % 2 == 0)) && ch="*" || ch="."
    elif ((si % 3 == 0)); then
      ((F / 4 % 2 == 0)) && ch="*" || ch=" "
    else
      ((F % 3 == 0)) && ch="." || { ((F % 7 == 0)) && ch="*" || ch=" "; }
    fi
    if [[ -n "$ch" && "$ch" != " " ]]; then
      if ((si % 3 == 0)); then ltr=n; elif ((si % 7 == 0)); then ltr=o; else ltr=l; fi
      put_text $((sr + 1)) $((sc + 1)) "$ch" "$ltr"
    fi
  done

  # moon
  for ((r = 0; r < 7; r++)); do
    put_text $((2 + r)) 84 "${MOON[r]}" k
  done

  # shooting star  ~frame 34..43
  if ((F >= 34 && F < 44)); then
    t=$((F - 34))
    for ((k = 0; k <= 5; k++)); do
      rr=$((3 + t + k)); cc=$((76 - t * 2 - k * 3))
      if ((rr < 13 && cc > 2)); then
        ((k == 0)) && put_text $((rr + 1)) $((cc + 1)) "*" l || put_text $((rr + 1)) $((cc + 1)) "." l
      fi
    done
  fi

  # sloop glides across with a gentle bob (smoothstep ease-in/out)
  if ((F >= 12 && F < 60)); then
    bt=$((F - 12))
    t=$(( bt * 100 / 48 ))
    ease=$(( t * t * (300 - 2 * t) / 10000 ))
    bc=$(( 2 + ease * 66 / 100 ))
    s=$(( F % 26 ))
    bob=0
    (( s >= 5 && s < 12 )) && bob=1
    for ((r = 0; r < 8; r++)); do put_text $((5 + bob + r)) "$bc" "${SAIL[r]}" l; done
    for ((r = 0; r < 6; r++)); do put_text $((13 + bob + r)) "$bc" "${HULL[r]}" m; done
  fi

  # title reveal
  if ((F >= 70)); then
    visible=$(( (F - 70) / 2 + 1 ))
    ((visible > 9)) && visible=9
    charw=0
    for ((li = 0; li < visible; li++)); do charw=$((charw + WID[li] + 1)); done
    ((charw > 0)) && charw=$((charw - 1))
    for ((row = 0; row < 7; row++)); do
      put_text $((11 + row)) "$TITLEC" "${TITLE[row]:0:charw}" "${GOLDL[$(( (F / 2 + row) % 8 ))]}"
    done
    if ((F >= 78)); then
      put_text 19 "$TAGC" "$TAG" w
    fi
  fi

  if [[ "$show_msg" == "1" ]]; then
    put_text 21 "$MSGC" "$MSG" x
  fi
}

# emit_frame -> one write, no tearing (dirty rows emitted as base + sorted overlay segments)
emit_frame() {
  local -a rows
  local row i k j v vstart pstart ent line base_ltr
  for ((row = 0; row < HEIGHT; row++)); do
    if ((!DIRTY[row])); then
      rows[row]="${CSEQL[${crow[row]:0:1}]}${screen[row]}${ESC}[0m"
      continue
    fi
    IFS=';' read -r -a ent <<<"${OVC[row]}"
    for ((k = 1; k < ${#ent[@]}; k++)); do
      v=${ent[k]}
      vstart=${v%%:*}
      j=$k
      while ((j > 0)); do
        pstart=${ent[j - 1]%%:*}
        ((vstart < pstart)) || break
        ent[j]=${ent[j - 1]}
        j=$((j - 1))
      done
      ent[j]=$v
    done
    base_ltr=${crow[row]:0:1}
    line=""
    k=0
    for ((i = 0; i < ${#ent[@]}; i++)); do
      v=${ent[i]}
      vstart=${v%%:*}
      vlen=${v#*:}; vlen=${vlen%%:*}
      line+="${CSEQL[$base_ltr]}${screen[row]:k:$((vstart - k))}"
      line+="${CSEQL[${v##*:}]}${screen[row]:vstart:vlen}"
      k=$((vstart + vlen))
    done
    line+="${CSEQL[$base_ltr]}${screen[row]:k:$((WIDTH - k))}${ESC}[0m"
    rows[row]="$line"
  done
  printf '%s' "${ESC}[H"
  printf '%s\n' "${rows[@]}"
}

trap 'printf "\x1b[0m\x1b[?25h\x1b[%d;1H" "$HEIGHT"' EXIT
printf '\x1b[?25l\x1b[2J'

F=0
while :; do
  if ((NFRAMES > 0 && F >= NFRAMES)); then break; fi
  build_scene "$F" 0
  emit_frame
  sleep 0.05
  F=$((F + 1))
done

# final banner
printf '\x1b[2J'
build_scene 200 1
emit_frame
printf '\x1b[%d;1H\x1b[0m' "$HEIGHT"

if ((HOLD == 1)); then
  read -r -n 1 -s -p ""
fi
