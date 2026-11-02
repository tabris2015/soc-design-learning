#!/usr/bin/env bash
# Install Quartus Prime Pro 25.1.1 unattended, with Agilex 5 device support.
#
# Why 25.1.1 and not the newest release: Terasic's DE25-Nano golden_top project and
# Linux image are built with it, so their projects open without IP upgrades.
#
# Altera's download site needs a logged-in browser, so fetch these by hand into
# ~/Downloads/quartus-pro/25.1.1/ first:
#   QuartusProSetup-25.1.1.125-linux.run
#   QuartusProSetup-part2-25.1.1.125-linux.qdz
#   agilex5-25.1.1.125.qdz
#   agilex_common-25.1.1.125.qdz
# The installer picks up the .qdz files sitting next to it, so device support is
# limited to what you downloaded.
#
# Usage:  ./scripts/install-quartus-pro.sh [download-dir] [install-dir]
set -euo pipefail

DL="${1:-$HOME/Downloads/quartus-pro/25.1.1}"
INSTALLDIR="${2:-$HOME/altera_pro/25.1.1}"
RUN="$DL/QuartusProSetup-25.1.1.125-linux.run"

for f in "$RUN" "$DL/QuartusProSetup-part2-25.1.1.125-linux.qdz" \
         "$DL/agilex5-25.1.1.125.qdz" "$DL/agilex_common-25.1.1.125.qdz"; do
    [ -f "$f" ] || { echo "!! missing $f" >&2; exit 1; }
done
chmod +x "$RUN"

# Install only what we have files for. The installer's --help lists every
# component on its "Allowed:" line under --disable-components; disable all of
# them except the base tool and Agilex 5. Device families, Questa, RiscFree,
# DSP Builder, help and the EDA libraries ship as separate files we didn't
# download, and an unattended install with one of them selected but missing
# can fail. devinfo, quartus_update and export_controlled come inside the base
# installer, so they stay.
KEEP="quartus devinfo agilex5 agilex_common quartus_update export_controlled"
allowed=$("$RUN" --help 2>&1 | sed -n '/--disable-components/,/--installdir/s/^ *Allowed: *//p' | tr ' ' '\n' | grep -E '^[a-z0-9_]+$' || true)
[ -n "$allowed" ] || { echo "!! couldn't read the component list from $RUN --help" >&2; exit 1; }
DISABLE=""
for c in $allowed; do
    grep -qwx "$c" <<<"$(tr ' ' '\n' <<<"$KEEP")" || DISABLE="${DISABLE:+$DISABLE,}$c"
done

echo "==> Installing Quartus Prime Pro 25.1.1"
echo "    installer: $RUN"
echo "    target:    $INSTALLDIR"
echo "    disabling: ${DISABLE:-nothing}"
echo "    This takes a while and prints little."
"$RUN" --mode unattended --accept_eula 1 --installdir "$INSTALLDIR" \
    ${DISABLE:+--disable-components "$DISABLE"}

echo
echo "==> Verifying"
Q="$INSTALLDIR/quartus/bin"
"$Q/quartus_sh" --version | head -3
# quartus_sh --tcl_eval can't load the device package, so the query needs a
# script file. The DE25-Nano's part must be in the list.
PART=A5EB013BB23BE4SCS
tcl=$(mktemp --suffix=.tcl)
cat > "$tcl" <<EOF
load_package device
set parts [get_part_list -family "Agilex 5"]
puts "parts [llength \$parts]"
foreach p \$parts { if {[string match -nocase $PART \$p]} { puts "found \$p" } }
EOF
out=$(cd "$(dirname "$tcl")" && "$Q/quartus_sh" -t "$tcl" 2>&1)
rm -f "$tcl"
echo "    Agilex 5 parts available: $(sed -n 's/^parts //p' <<<"$out")"
if grep -q '^found' <<<"$out"; then
    echo "    OK: $PART is supported"
else
    echo "!! $PART not found. quartus_sh said:" >&2; tail -5 <<<"$out" >&2; exit 1
fi
cat <<EOF

Add to your shell when working on the DE25-Nano:
    export PATH="$Q:\$PATH"
Then get the free Agilex 5 E licence: quartus, then Tools > License Setup >
Get no-cost licenses > Agilex 5 E-Series. It is tied to this PC's network card.
EOF
