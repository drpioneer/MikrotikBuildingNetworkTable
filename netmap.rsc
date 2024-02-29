# Script for building a network table by drPioneer
# https://forummikrotik.ru/viewtopic.php?p=92265#p92265
# tested on ROS 6.49.10 & 7.12
# updated 2024/02/29

:global outNetMap;
:do {
  :local myFile ""; # file name, for example "nmap.txt"
#  /tool ip-scan duration=30s; # tool ip-scan list for switch

  # interface list
  :local ifcCnt 0; :local ifc {"";"";"";""};
  /interface;
  :foreach ifcIdx in=[find running=yes] do={
    :local ifcNam [get $ifcIdx name];
    :local ifcMac [get $ifcIdx mac-address];
    :local ifcCmt [get $ifcIdx comment];
    :local ifcHst [/system identity get name];
    :set ($ifc->$ifcCnt) {$ifcNam;$ifcHst;$ifcMac;$ifcCmt};
    :set ifcCnt ($ifcCnt+1);
  }
  :set ifcCnt ($ifcCnt-1);

  # bridge host list
  :local hstCnt 0; :local hst {"";"";"";"";"";""};
  /interface bridge host;
  :foreach hstIdx in=[find] do={
    :do {
      :local hstCmt ""; :local hstNam ""; :local hstIpa "";
      :local hstIfc [get $hstIdx on-interface];
      :local hstMac [get $hstIdx mac-address];
      :local hstBrg [get $hstIdx bridge];
      :if ([get $hstIdx local]=true) do={ 
        :set hstNam [/system identity get name];
        :set hstIpa [/ip address get [find interface=$hstBrg] address];
      } else={
        /ip dhcp-server lease;
        :do {
          :set hstNam [get [find mac-address=$hstMac] host-name];
          :set hstIpa [get [find mac-address=$hstMac] address];
          :set hstCmt [get [find mac-address=$hstMac] comment];
        } on-error={
          :set hstNam [get [find mac-address=$hstMac dynamic=yes] host-name];
          :set hstIpa [get [find mac-address=$hstMac dynamic=yes] address];
        }
      }
      :set ($hst->$hstCnt) {$hstIfc;$hstNam;$hstMac;$hstIpa;$hstBrg;$hstCmt};
      :set hstCnt ($hstCnt+1);
    } on-error={}
  }
  :set hstCnt ($hstCnt-1);

  # ip address list
  :local ipaCnt 0; :local ipa {"";"";"";""};
  /ip address;
  :foreach ipaIdx in=[find] do={
    :local ipaIfc [get $ipaIdx interface];
    :local ipaAdr [get $ipaIdx address];
    :local ipaNet [get $ipaIdx network];
    :local ipaCmt [get $ipaIdx comment];
    :set ($ipa->$ipaCnt) {$ipaIfc;$ipaAdr;$ipaNet;$ipaCmt};
    :set ipaCnt ($ipaCnt+1);
  }
  :set ipaCnt ($ipaCnt-1);

  # ip arp list
  :local arpCnt 0; :local arp {"";"";"";"";""};
  /ip arp;
  :foreach arpIdx in=[find] do={
    :local arpIfc [get $arpIdx interface];
    :local arpIpa [get $arpIdx address];
    :local arpMac [get $arpIdx mac-address];
    :local arpCmt [get $arpIdx comment];
    :local arpNet "";
    :do {:set arpNet [/ip dhcp-client get [find interface=$arpIfc] gateway]} on-error={}
    :if ($arpNet=$arpIpa) do={:set arpNet "GATEWAY"}
    :local equMac false;
    :for i from=0 to=$hstCnt do={
      :local fndDst [:find key=$arpMac in=($hst->$i)];
      :if ([:tostr [$fndDst]]!="") do={:set equMac true}
    }
    :if ($equMac=false) do={
      :do {
        /interface bridge host;
        :if ([get [find mac-address=$arpMac] on-interface]!="") do={
          :set arpNet $arpIfc;
          :set arpIfc [get [find mac-address=$arpMac] on-interface];
        }
      } on-error={}
      :set ($arp->$arpCnt) {$arpIfc;$arpMac;$arpIpa;$arpCmt;$arpNet};
      :set arpCnt ($arpCnt+1);
    }
  }
  :set arpCnt ($arpCnt-1);

  # build list
  :local arrIdx 1; :local arr {"";"";"";"";"";"";""};
  :set ($arr->0) {"NUMBER";"INTERFACE";"HOST-NAME";"MAC-ADDRESS";"IP-ADDRESS";"NETWORK";"REMARK"};
  :set ($arr->1) {"";"";"";"";"";"";""};
  :for i from=0 to=$ifcCnt do={
    :for j from=0 to=$hstCnt do={
      :local fndDst [:find key=($hst->$j->0) in=($ifc->$i)];
      :if ([:tostr [$fndDst]]!="" && ($hst->$j->4)!=($hst->$j->0)) do={
        :if (($hst->$j->2)=($ifc->$i->2)) do={
          :set ($arr->$arrIdx) {$arrIdx;($hst->$j->0);($hst->$j->1);($hst->$j->2);($hst->$j->3);($hst->$j->4);($ifc->$i->3)}; 
        } else={
          :set ($arr->$arrIdx) {$arrIdx;($hst->$j->0);($hst->$j->1);($hst->$j->2);($hst->$j->3);($hst->$j->4);($hst->$j->5)}; 
        }
        :set arrIdx ($arrIdx+1);
      }
    }
    :for j from=0 to=$arpCnt do={
      :local fndDst [:find key=($arp->$j->0) in=($ifc->$i)];
      :if ([:tostr [$fndDst]]!="") do={
        :set ($arr->$arrIdx) {$arrIdx;($arp->$j->0);"";($arp->$j->1);($arp->$j->2);($arp->$j->4);($arp->$i->3)}; 
        :set arrIdx ($arrIdx+1);
      }
    }
    :for j from=0 to=$ipaCnt do={
      :local fndDst [:find key=($ifc->$i->0) in=($ipa->$j)];
      :if ([:tostr [$fndDst]]!="") do={
        :set ($arr->$arrIdx) {$arrIdx;($ifc->$i->0);($ifc->$i->1);($ifc->$i->2);($ipa->$j->1);($ipa->$j->2);($ifc->$i->3)}; 
        :set arrIdx ($arrIdx+1);
      }
    }
  }
  :set arrIdx ($arrIdx-1);

  # output list
  :local TextCut do={:return [:pick "$1                                             " 0 $2]}
  :for i from=0 to=$arrIdx do={
    :set outNetMap ("$outNetMap\r\n$[$TextCut ($arr->$i->0) 3]\t$[$TextCut ($arr->$i->3) 17]\t$[$TextCut ($arr->$i->4) 18]\t\
    $[$TextCut ($arr->$i->1) 18]\t$[$TextCut ($arr->$i->5) 15]\t$[$TextCut ($arr->$i->2) 21]\t$[$TextCut ($arr->$i->6) 35]");
  }
  :put ("---------------------------------------------------------------------------------------------------------------------------$outNetMap");
  :if ([:len $myFile]!=0) do={
    :local fileName ("$[/system identity get name]_$myFile");
    :execute script=":global outNetMap; :put (\"$outNetMap\");" file=$fileName;
    :put ("File '$fileName' was successfully created");
  } else={:put ("File creation is not enabled")}
} on-error={:put "Problem in work 'NetMap' script"}
:delay 1s; # time delay between command executing and remove global variables
/system script environment remove [find name~"outNetMap"];
