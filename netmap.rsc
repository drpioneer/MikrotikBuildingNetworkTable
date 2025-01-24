# Script for building a network map by drPioneer
# https://forummikrotik.ru/viewtopic.php?p=92265#p92265
# https://github.com/drpioneer/MikrotikBuildingNetworkTable
# checked on ROS 6.49.17 & 7.16.2
# updated 2025/01/24

:global outNetMap "";:local sysId [/system identity get name]
:do {
  :local myFile ""; # file name, for example "nmap.txt"
  :local log false; # maintaining log entries (false / true)
  :local debug false; # debug mode (false / true)
  #/tool ip-scan duration=30s; # using ip-scan tool (uncomment if necessary)

  # reading data
  :local ifc {"if";"";"mac";"";"";"rem"};:local idxIfc -1; # interface list
  /interface;find;:foreach id in=[find running=yes] do={:set idxIfc ($idxIfc+1)
    :set ($ifc->$idxIfc) {[get $id name];"";[get $id mac-address];"";"";[get $id comment]}}
  :local brg {"if";"";"mac";"";"brg";"lcl/rem"};:local idxBrg -1; # bridge-host list
  /interface bridge host;find;:foreach id in=[find disabled=no] do={:set idxBrg ($idxBrg+1)
    :set ($brg->$idxBrg) {[get $id on-interface];"";[get $id mac-address];"";[get $id bridge];[get $id local]}}
  :local dhS {"";"hst";"mac";"ip";"";"rem"};:local idxDhS -1; # dhcp-server list
  /ip dhcp-server lease;find;:foreach id in=[find mac-address~":"] do={:set idxDhS ($idxDhS+1)
    :set ($dhS->$idxDhS) {"";[get $id host-name];[get $id mac-address];[get $id address];"";[get $id comment]}}
  :local dhC {"if";"gw";"";"ip";"";"rem"};:local idxDhC -1; # dhcp-client list
  /ip dhcp-client;find;:foreach id in=[find status=bound] do={:set idxDhC ($idxDhC+1)
    :set ($dhC->$idxDhC) {[get $id interface];[get $id gateway];"";[get $id address];"";[get $id comment]}}
  :local adr {"if";"";"";"ip";"netw";""};:local idxAdr -1; # ip-address list
  /ip address;find;:foreach id in=[find disabled=no] do={:set idxAdr ($idxAdr+1)
    :set ($adr->$idxAdr) {[get $id interface];"";"";[get $id address];[get $id network];""}}
  :local arp {"if";"";"mac";"ip";"";""};:local idxArp -1; # ip-arp list
  /ip arp;find;:foreach id in=[find complete=yes] do={:set idxArp ($idxArp+1)
    :set ($arp->$idxArp) {[get $id interface];"";[get $id mac-address];[get $id address];"";""}}
  :local rou {"gw";"";"";"";"netw";""};:local idxRou -1; # ip-arp list
  /ip route;find;:foreach id in=[find] do={:set idxRou ($idxRou+1)
    :set ($rou->$idxRou) {[get $id gateway];"";"";"";[get $id dst-address];""}}
  :local tar {"if";"hst";"mac";"ip";"netw";"rem"};:local idxTar 0; # target list
  /;:set ($tar->0) {"INTERFACE";"NAME";"MAC-ADDRESS";"IP-ADDRESS";"NETWORK";"REMARK"}

  # data processing
  :for i from=0 to=$idxAdr do={ # filling of 'ip address' list
    :for j from=0 to=$idxIfc do={
      :if (($adr->$i->0)=($ifc->$j->0)) do={ # when equal 'interface' in 'ip address'&'interface' lists ->
        :set ($adr->$i->1) ($ifc->$j->0);:set ($adr->$i->2) ($ifc->$j->2)}}
    :for j from=0 to=$idxDhC do={
      :if (($adr->$i->0)=($dhC->$j->0)&&($adr->$i->3)=($dhC->$j->3)) do={ # when equal 'interface/ip' in 'ip address'&'dhcp-client' lists ->
        :set ($adr->$i->1) "GW:$($dhC->$j->1)";:set ($adr->$i->5) ($dhC->$j->5)}}
    :if ($debug) do={:put "adr $i $($adr->$i)"}}
  :for i from=0 to=$idxBrg do={ # filling of 'bridge host' list
    :set ($brg->$i->1) $sysId;:set ($brg->$i->3) ($brg->$i->4);:set ($brg->$i->5) "on $($brg->$i->0) interface"
    :for j from=0 to=$idxDhS do={
      :if (($brg->$i->2)=($dhS->$j->2)) do={ # when equal 'mac' in 'bridge-hosts'&'dhcp-server' lists ->
        :set ($brg->$i->1) ($dhS->$j->1);:set ($brg->$i->3) ($dhS->$j->3);:set ($brg->$i->5) ($dhS->$j->5)}}
    :for j from=0 to=$idxAdr do={
      :if (($brg->$i->0)=($adr->$j->0)) do={ # when equal 'interface' in 'bridge-hosts'&'ip-address' lists ->
        :set ($brg->$i->1) ($adr->$j->1);:set ($brg->$i->3) ($adr->$j->3);:set ($brg->$i->4) ($adr->$j->4)
        :set ($brg->$i->5) ($adr->$j->5)}}
    :if ($debug) do={:put "brg $i $($brg->$i)"}}
  :for i from=0 to=$idxArp do={ # filling of 'ip arp' list
    :for j from=0 to=$idxDhS do={
      :if (($arp->$i->2)=($dhS->$j->2)&&($arp->$i->3)=($dhS->$j->3)) do={ # when equal 'mac/ip' in 'dhcp-server'&'ip arp' lists ->
        :set ($arp->$i->0) ($dhS->$j->0);:set ($arp->$i->1) ($dhS->$j->1);:set ($arp->$i->5) ($dhS->$j->5)}}
    :for j from=0 to=$idxAdr do={
      :if (($arp->$i->3)=($adr->$j->3)) do={ # when equal 'ip' in 'ip address'&'ip arp' lists ->
        :set ($arp->$i->0) ($adr->$j->0);:set ($arp->$i->1) ($adr->$j->1);:set ($arp->$i->4) ($adr->$j->4)
        :set ($arp->$i->5) ($adr->$j->5)}}
    :for j from=0 to=$idxBrg do={
      :if (($arp->$i->2)=($brg->$j->2)) do={ # when equal 'mac' in 'bridge-hosts'&'ip arp' lists ->
        :set ($arp->$i->0) ($brg->$j->0);:set ($arp->$i->1) ($brg->$j->1);:set ($arp->$i->3) ($brg->$j->3)
        :set ($arp->$i->4) ($brg->$j->4);:set ($arp->$i->5) ($brg->$j->5)}}
    :if ($debug) do={:put "arp $i $($arp->$i)"}}
  :for i from=0 to=$idxIfc do={ # filling of 'target' list
    :for j from=0 to=$idxAdr do={
      :if (($ifc->$i->0)=($adr->$j->0)) do={ # when equal 'interface' in 'interface'&'ip address' lists ->
        :if ([:len [:find key=($adr->$j) in=$tar]]=0) do={ # when elements of target array are not repeated ->
          :set idxTar ($idxTar+1);:set ($tar->$idxTar) ($adr->$j)}}}
    :for j from=0 to=$idxArp do={
      :if (($ifc->$i->0)=($arp->$j->0)) do={ # when equal 'interface' in 'interface'&'ip arp' lists ->
        :if ([:len [:find key=($arp->$j) in=$tar]]=0) do={ # when elements of target array are not repeated ->
          :set idxTar ($idxTar+1);:set ($tar->$idxTar) ($arp->$j)}}}
    :for j from=0 to=$idxBrg do={
      :if (($ifc->$i->0)=($brg->$j->0)&&($ifc->$i->2)=($brg->$j->2)) do={ # when equal interface/mac in 'interface'&'bridge-hosts' lists ->
        :if ([:len [:find key=($brg->$j) in=$tar]]=0) do={ # when elements of target array are not repeated ->
          :set idxTar ($idxTar+1);:set ($tar->$idxTar) ($brg->$j)}}}
    :if ($debug) do={:put "ifc $i $($ifc->$i)"}}
  :for i from=0 to=$idxTar do={ # adding elements to 'target' list
    :for j from=0 to=$idxRou do={
      :if (($tar->$i->0)=($rou->$j->0)) do={ # when equal 'interface' in 'target'&'ip-route' lists ->
        :set ($tar->$i->4) ($rou->$j->4)}}
    :for j from=0 to=$idxAdr do={
      :if (($tar->$i->3)=($adr->$j->0)&&($tar->$i->3)=($tar->$i->4)) do={ # when equal 'ip-addr'&'network' in 'target' lists ->
        :set ($tar->$i->3) ($adr->$j->3)}}
    :if ($debug) do={:put "tar $i $($tar->$i)"}}

  # data output
  :local TxtCut do={:return [:pick "$1                                             " 0 $2]};
  :if ($debug) do={:put "Active elements: intf:$idxIfc brg-hst:$idxBrg dhcp-srv-lease:$idxDhS dhcp-clnt:$idxDhC \
    ip-addr:$idxAdr ip-arp:$idxArp ip-rout:$idxRou target:$idxTar"}
  :for i from=0 to=$idxTar do={
    :set outNetMap "$outNetMap\r\n$[$TxtCut $i 3]  $[$TxtCut ($tar->$i->0) 22]  $[$TxtCut ($tar->$i->2) 17]  \
      $[$TxtCut ($tar->$i->3) 18]  $[$TxtCut ($tar->$i->4) 18]  $[$TxtCut ($tar->$i->1) 18]  $[$TxtCut ($tar->$i->5) 30]"}
  :set outNetMap "List of active network devices:\r\n----------------------------------------------------------------------\
    ----------------------------------------------------------------$outNetMap"
  :put $outNetMap;:if ($log) do={/log warning $outNetMap}
  :if ([:len $myFile]!=0) do={:local fileName ("$sysId_$myFile")
    :execute script=":global outNetMap;:put (\"$outNetMap\")" file=$fileName
    :put ("File '$fileName' was successfully created")
  } else={:put ("File creation is not enabled")}
} on-error={:put "Problem in work 'NetMap' script"}
:delay 1s; # time delay between command executing & remove global variable
/system script environment remove [find name~"outNetMap"]
