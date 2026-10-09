#!/usr/bin/env bash
# Read-only audit of the native request/response probe reports. Capture count
# must come from the fitted inventory, not be inferred from passing reports.
set -euo pipefail
[[ $# == 2 && -d "$1" && "$2" =~ ^(8|9|1[0-6])$ ]] || {
  echo 'usage: audit_pcg_timing_reports.sh REPORT_DIR FITTED_CPU_CAPTURE_COUNT(8..16)' >&2
  exit 2
}
report_dir="$1"
capture_count="$2"
audit() {
  local report="$1" group="$2" expected="$3" bound="$4"
  [[ -f "$report" ]] || { echo "Missing report: $report" >&2; return 1; }
  LC_ALL=C awk -F';' -v group="$group" -v expected="$expected" -v bound="$bound" '
    NF==10 && $3~/x1_pcg_access:cg_bus/ {
      for(i=2;i<=9;i++)gsub(/^ +| +$/,"",$i)
      n++; s=$2; delay=$9
      if(s !~ /^-?[0-9]+\.[0-9]+$/ || delay !~ /^[0-9]+\.[0-9]+$/ || s+0<0 || delay+0>=bound)bad=1
      src=$3; dst=$4
      if(group=="response") {
        if(src !~ /\|response\[[0-7]\]$/ || dst !~ /\|cpu_q\[[0-7]\](~DUPLICATE)?$/)bad=1
        a=src;b=dst;sub(/^.*\|response\[/,"",a);sub(/\].*$/,"",a)
        sub(/^.*\|cpu_q\[/,"",b);sub(/\].*$/,"",b);if(a!=b)bad=1
        if(dst !~ /~DUPLICATE$/)primary[b]=1
        if(seen[dst]++)bad=1
        if($5 !~ /turbo_video_pll/ || $6 !~ /\|pll\|pll_inst\|/)bad=1
      } else {
        if($5 !~ /\|pll\|pll_inst\|/ || $6 !~ /turbo_video_pll/)bad=1
        if(group=="address") {
          if(src !~ /\|frozen_addr\[[0-3]\]$/ && src !~ /\|font_cpu_addr\[([0-9]|1[01])\]$/)bad=1
          if(dst !~ /\|access_addr\[([0-9]|10)\]$/)bad=1
          bit=dst;sub(/^.*\|access_addr\[/,"",bit);sub(/\].*$/,"",bit);address_bits[bit]=1
          if(seen[dst]++)bad=1
        } else if(group=="payload") {
          if(src !~ /\|payload\[[0-7]\]$/ || dst !~ /x1_video_ram:pcg_[brg]\|.*~(PORT_A_DATA_IN_[0-9]+|porta_datain_reg[0-9]+)$/)bad=1
          if(seen[dst]++)bad=1
          payload_sources[src]=1
          color=dst;sub(/^.*x1_video_ram:pcg_/,"",color);sub(/\|.*$/,"",color);planes[color]++
        } else if(group=="control") {
          if(src !~ /\|(plane\[[01]\]|write_request|high_speed_request|unsupported_request)$/)bad=1
          if(dst !~ /\|(access_addr\[([0-9]|10)\]|response\[[0-7]\]|seen|stage\.(00|01|10)|stage\.01~DUPLICATE)$/ && dst !~ /x1_video_ram:pcg_[brg]\|.*~porta_we_reg$/)bad=1
          control_sources[src]=1
          if(!(dst in control_destinations)) {
            control_destinations[dst]=1;control_dest_count++
            if(dst~/~porta_we_reg$/) {
              color=dst;sub(/^.*x1_video_ram:pcg_/,"",color);sub(/\|.*$/,"",color);we_planes[color]++
            } else {parts=split(dst,leaves,"|");control_leaves[leaves[parts]]=1}
          }
        } else bad=1
      }
    }
    END {
      if(group=="response")for(i=0;i<8;i++)if(!(i in primary))bad=1
      if(group=="address")for(i=0;i<11;i++)if(!(i in address_bits))bad=1
      if(group=="control") {
        for(src in control_sources)source_count++
        if(source_count!=5 || control_dest_count!=35 || we_planes["b"]!=4 || we_planes["r"]!=4 || we_planes["g"]!=4)bad=1
        for(i=0;i<11;i++)if(!(("access_addr["i"]") in control_leaves))bad=1
        for(i=0;i<8;i++)if(!(("response["i"]") in control_leaves))bad=1
        if(!("seen" in control_leaves) || !("stage.00" in control_leaves) || !("stage.01" in control_leaves) || !("stage.01~DUPLICATE" in control_leaves))bad=1
      }
      if(group=="payload" && (planes["b"]!=64 || planes["r"]!=64 || planes["g"]!=64))bad=1
      if(group=="payload") {for(src in payload_sources)payload_source_count++;if(payload_source_count!=8)bad=1}
      if(n!=expected || bad){print "FAIL:",FILENAME,"group="group,"paths="n,"expected="expected > "/dev/stderr";exit 1}
    }' "$report"
}
for model in slow fast; do
  for temperature in -40 0 85 100; do
    for check in setup hold; do
      corner="${model}_${temperature}"
      audit "$report_dir/sharpx1_turbo_z_video_pcg_request_probe_${corner}_address_${check}.rpt" address 11 23.28
      audit "$report_dir/sharpx1_turbo_z_video_pcg_request_probe_${corner}_control_${check}.rpt" control 90 23.28
      audit "$report_dir/sharpx1_turbo_z_video_pcg_request_probe_${corner}_payload_${check}.rpt" payload 192 23.28
      audit "$report_dir/sharpx1_turbo_z_video_pcg_response_probe_${corner}_response_${check}.rpt" response "$capture_count" 31.25
    done
  done
done
echo "PASS: 48 request and 16 response corner reports; all $capture_count CPU captures and eight primary bits timed"
