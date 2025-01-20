# Script for building a network table by drPioneer
# https://forummikrotik.ru/viewtopic.php?p=92265#p92265
# https://github.com/drpioneer/MikrotikBuildingNetworkTable
# checked on ROS 6.49.17 & 7.16.2
# updated 2025/01/21

:global outNetMap; :local sysId [/system identity get name]; 
:do {
#  /tool ip-scan duration=30s; # ip-scan list
  :local myFile ""; # file name, for example "nmap.txt"
  :local debug false; # debug mode: true=>is active / false=>is inactive

  # reading data
  :local ifc {"intf";"";"mac";"";"";"rem"}; :local idxIfc -1; # interface list
  /interface; find; :foreach id in=[find running=yes] do={:set idxIfc ($idxIfc+1)
    :set ($ifc->$idxIfc) {[get $id name];"";[get $id mac-address];"";"";[get $id comment]}}
  :local brg {"intf";"";"mac";"";"brdg";"rem";"loc"}; :local idxBrg -1; # bridge-host list
  /interface bridge host; find; :foreach id in=[find disabled=no] do={:set idxBrg ($idxBrg+1)
    :set ($brg->$idxBrg) {[get $id on-interface];"";[get $id mac-address];"";[get $id bridge];"";[get $id local]}}
  :local dhS {"";"host";"mac";"ip";"";"rem"}; :local idxDhS -1; # dhcp-server list
  /ip dhcp-server lease; find; :foreach id in=[find active-mac-address~":"] do={:set idxDhS ($idxDhS+1)
    :set ($dhS->$idxDhS) {"";[get $id host-name];[get $id mac-address];[get $id address];"";[get $id comment]}}
  :local dhC {"intf";"gw";"";"ip";"";"rem"}; :local idxDhC -1; # dhcp-client list
  /ip dhcp-client; find; :foreach id in=[find status=bound] do={:set idxDhC ($idxDhC+1)
    :set ($dhC->$idxDhC) {[get $id interface];[get $id gateway];"";[get $id address];"";[get $id comment]}}
  :local adr {"intf";"";"";"ip";"netw";""}; :local idxAdr -1; # ip-address list
  /ip address; find; :foreach id in=[find disabled=no] do={:set idxAdr ($idxAdr+1)
    :set ($adr->$idxAdr) {[get $id interface];"";"";[get $id address];[get $id network];""}}
  :local arp {"intf";"";"mac";"ip";"";""}; :local idxArp -1; # ip-arp list
  /ip arp; find; :foreach id in=[find complete=yes] do={:set idxArp ($idxArp+1)
    :set ($arp->$idxArp) {[get $id interface];"";[get $id mac-address];[get $id address];"";""}}
  :local rou {"gw";"";"";"";"netw";""}; :local idxRou -1; # ip-arp list
  /ip route; find; :foreach id in=[find] do={:set idxRou ($idxRou+1)
    :set ($rou->$idxRou) {[get $id gateway];"";"";"";[get $id dst-address];""}}
  :local arr {"intf";"host";"mac";"ip";"netw";"rem"}; :local idxArr 0; # build list
  /; :set ($arr->0) {"INTERFACE";"NAME";"MAC-ADDRESS";"IP-ADDRESS";"NETWORK";"REMARK"}

  # data processing
  :for i from=0 to=$idxAdr do={
    :for j from=0 to=$idxIfc do={
      :if (($adr->$i->0)=($ifc->$j->0)) do={ # when equal 'interface' in 'ip address'&'interface' lists ->
        :set ($adr->$i->1) ($ifc->$j->0); :set ($adr->$i->2) ($ifc->$j->2)}}
    :for j from=0 to=$idxDhC do={
      :if (($adr->$i->0)=($dhC->$j->0)&&($adr->$i->3)=($dhC->$j->3)) do={ # when equal 'interface/ip' in 'ip address'&'dhcp-client' lists ->
        :set ($adr->$i->1) "GW:$($dhC->$j->1)"; :set ($adr->$i->5) ($dhC->$j->5)}}
    :if ($debug) do={:put "adr $i $($adr->$i)"}}
  :for i from=0 to=$idxBrg do={
    :if (($brg->$i->6)=true) do={ # when 'bridge-host' is 'local'
      :set ($brg->$i->1) $sysId; :set ($brg->$i->3) ($brg->$i->4)}
    :for j from=0 to=$idxDhS do={
      :if (($brg->$i->2)=($dhS->$j->2)) do={ # when equal 'mac' in 'bridge-hosts'&'dhcp-server' lists ->
        :set ($brg->$i->1) ($dhS->$j->1); :set ($brg->$i->3) ($dhS->$j->3)
        :set ($brg->$i->5) ($dhS->$j->5)}}
    :for j from=0 to=$idxAdr do={
      :if (($brg->$i->0)=($adr->$j->0)) do={ # when equal 'interface' in 'bridge-hosts'&'ip-address' lists ->
          :set ($brg->$i->1) ($adr->$j->1); :set ($brg->$i->3) ($adr->$j->3)
          :set ($brg->$i->4) ($adr->$j->4); :set ($brg->$i->5) ($adr->$j->5)}}
    :if ($debug) do={:put "brg $i $($brg->$i)"}}
  :for i from=0 to=$idxArp do={
    :for j from=0 to=$idxDhS do={
      :if (($arp->$i->2)=($dhS->$j->2)&&($arp->$i->3)=($dhS->$j->3)) do={ # when equal 'mac/ip' in 'dhcp-server'&'ip arp' lists ->
        :set ($arp->$i->0) ($dhS->$j->0); :set ($arp->$i->1) ($dhS->$j->1)
        :set ($arp->$i->5) ($dhS->$j->5)}}
    :for j from=0 to=$idxAdr do={
      :if (($arp->$i->3)=($adr->$j->3)) do={ # when equal 'ip' in 'ip address'&'ip arp' lists ->
        :set ($arp->$i->0) ($adr->$j->0); :set ($arp->$i->1) ($adr->$j->1);
        :set ($arp->$i->4) ($adr->$j->4); :set ($arp->$i->5) ($adr->$j->5)}}
    :for j from=0 to=$idxBrg do={
      :if (($arp->$i->2)=($brg->$j->2)) do={ # when equal 'mac' in 'bridge-hosts'&'ip arp' lists ->
        :set ($arp->$i->0) ($brg->$j->0); :set ($arp->$i->1) ($brg->$j->1); 
        :set ($arp->$i->3) ($brg->$j->3); :set ($arp->$i->4) ($brg->$j->4)
        :set ($arp->$i->5) ($brg->$j->5)}}
    :if ($debug) do={:put "arp $i $($arp->$i)"}}
  :for i from=0 to=$idxIfc do={
    :for j from=0 to=$idxAdr do={
      :if (($ifc->$i->0)=($adr->$j->0)) do={ # when equal 'interface' in 'interface'&'ip address' lists ->
        :set idxArr ($idxArr+1); :set ($arr->$idxArr) ($adr->$j)}}
    :for j from=0 to=$idxArp do={
      :if (($ifc->$i->0)=($arp->$j->0)) do={ # when equal 'interface' in 'interface'&'ip arp' lists ->
        :set idxArr ($idxArr+1); :set ($arr->$idxArr) ($arp->$j)}}
    :for j from=0 to=$idxBrg do={
      :if (($ifc->$i->0)=($brg->$j->0)&&($ifc->$i->2)=($brg->$j->2)) do={ # when equal interface/mac in 'interface'&'bridge-hosts' lists ->
        :set idxArr ($idxArr+1); :set ($arr->$idxArr) ($brg->$j)}}
    :if ($debug) do={:put "ifc $i $($ifc->$i)"}}
  :for i from=0 to=$idxArr do={
    :for j from=0 to=$idxRou do={
      :if (($arr->$i->0)=($rou->$j->0)) do={ # when equal 'interface' in 'target'&'ip-route' lists
        :set ($arr->$i->4) ($rou->$j->4)}}
    :for j from=0 to=$idxAdr do={
      :if (($arr->$i->3)=($adr->$j->0)&&($arr->$i->3)=($arr->$i->4)) do={ # when equal 'interface' in 'target'&'ip-route' lists
        :set ($arr->$i->3) ($adr->$j->3)}}
    :if ($debug) do={:put "arr $i $($arr->$i)"}}

  # data output
  :local TxtCut do={:return [:pick "$1                                             " 0 $2]}; # output list
  :if ($debug) do={:put "Active elements: intf:$idxIfc brg-hst:$idxBrg dhcp-srv-lease:$idxDhS dhcp-clnt:$idxDhC \
    ip-addr:$idxAdr ip-arp:$idxArp ip-rout:$idxRou target:$idxArr"}
  :for i from=0 to=$idxArr do={
    :set outNetMap "$outNetMap\r\n$[$TxtCut $i 3]  $[$TxtCut ($arr->$i->0) 22]  $[$TxtCut ($arr->$i->2) 17]  \
      $[$TxtCut ($arr->$i->3) 18]  $[$TxtCut ($arr->$i->4) 18]  $[$TxtCut ($arr->$i->1) 18]  $[$TxtCut ($arr->$i->5) 30]"}
  :set outNetMap "----------------------------------------------------------------------\
    ----------------------------------------------------------------$outNetMap"
  :put $outNetMap; # /log warning $outNetMap
  :if ([:len $myFile]!=0) do={:local fileName ("$sysId_$myFile")
    :execute script=":global outNetMap; :put (\"$outNetMap\");" file=$fileName
    :put ("File '$fileName' was successfully created")
  } else={:put ("File creation is not enabled")}
} on-error={:put "Problem in work 'NetMap' script"}
:delay 1s; # time delay between command executing and remove global variables
/system script environment remove [find name~"outNetMap"]
