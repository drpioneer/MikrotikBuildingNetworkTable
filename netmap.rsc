# Script for building a network table by drPioneer
# https://forummikrotik.ru/viewtopic.php?p=70575
# tested on ROS 6.49
# updated 2021/11/25

:do {
    # tools ip scan list
    /tool ip-scan duration=30s;
    
    # interface list
    :local interfaceIndexArray 0;
    :local interfaceArray {"";"";"";""};
    :foreach interfaceIndex in=[ /interface find running=yes; ] do={
        :local interfaceName         ([ /interface get $interfaceIndex name; ]);
        :local interfaceHost         ([ /system identity get name; ]);
        :local interfaceMAC          ([ /interface get $interfaceIndex mac-address; ]);
        :local interfaceComment      ([ /interface get $interfaceIndex comment; ]);
        :set ($interfaceArray->$interfaceIndexArray) {$interfaceName;$interfaceHost;$interfaceMAC;$interfaceComment};
        :set interfaceIndexArray ($interfaceIndexArray + 1);
    }
    :set interfaceIndexArray ($interfaceIndexArray - 1);

    # interface bridge host list
    :local bridgeHostIndexArray 0;
    :local bridgeHostArray {"";"";"";"";"";""};
    :foreach bridgeHost in=[ /interface bridge host find; ] do={
        :do {
            :local hostInterface     ([ /interface bridge host get $bridgeHost on-interface; ]);
            :local hostMAC           ([ /interface bridge host get $bridgeHost mac-address; ]);
            :local hostBridge        ([ /interface bridge host get $bridgeHost bridge; ]);
            :local hostComment       ("");
            :local hostName          ("");
            :local hostIP            ("");
            if ([ /interface bridge host get $bridgeHost local; ] = true) do={ 
                :set hostName        ([ /system identity get name; ]);
                :set hostIP          ([ /ip address get [ find interface=$hostBridge ] address; ]);
            } else={
                :do {
                    :set hostName    ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] host-name; ]);
                    :set hostIP      ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] address; ]);
                    :set hostComment ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] comment; ]);
                } on-error={ 
                    :set hostName    ([ /ip dhcp-server lease get [ find mac-address=$hostMAC dynamic=yes ] host-name; ]);
                    :set hostIP      ([ /ip dhcp-server lease get [ find mac-address=$hostMAC dynamic=yes ] address; ]);
                }
            }
            :set ($bridgeHostArray->$bridgeHostIndexArray) {$hostInterface;$hostName;$hostMAC;$hostIP;$hostBridge;$hostComment};
            :set bridgeHostIndexArray ($bridgeHostIndexArray + 1);
        } on-error={ }
    }
    :set bridgeHostIndexArray ($bridgeHostIndexArray - 1);

    # ip address list
    :local ipAddressIndexArray 0;
    :local ipAddressArray {"";"";"";""};
    :foreach ipAddress in=([ /ip address find; ]) do={
        :local ipAddressInterface    ([ /ip address get $ipAddress interface; ]); 
        :local ipAddressIP           ([ /ip address get $ipAddress address; ]); 
        :local ipAddressNetwork      ([ /ip address get $ipAddress network; ]);
        :local ipAddressComment      ([ /ip address get $ipAddress comment; ]);
        :set ($ipAddressArray->$ipAddressIndexArray) {$ipAddressInterface;$ipAddressIP;$ipAddressNetwork;$ipAddressComment};
        :set ipAddressIndexArray ($ipAddressIndexArray + 1);
    }
    :set ipAddressIndexArray ($ipAddressIndexArray - 1);

    # ip arp list
    :local ipArpIndexArray 0;
    :local ipArpArray {"";"";"";"";""}; 
    :foreach ipArp in=([ /ip arp find; ]) do={
        :local ipArpInterface        ([ /ip arp get $ipArp interface; ]); 
        :local ipArpMACAddress       ([ /ip arp get $ipArp mac-address; ]);
        :local ipArpIP               ([ /ip arp get $ipArp address; ]); 
        :local ipArpComment          ([ /ip arp get $ipArp comment; ]);
        :local ipArpNetwork          ("");
        :do { 
            :set ipArpNetwork        ([ /ip dhcp-client get [find interface=$ipArpInterface ] gateway ]); 
        } on-error={ }
        if ($ipArpNetwork = $ipArpIP) do={ :set ipArpNetwork ("GATEWAY"); }
        :local equalMACAddress (false);
        :for i from=0 to=$bridgeHostIndexArray do={
            :local findDestination [:find key=($ipArpMACAddress) in=($bridgeHostArray->$i)];
            if ([:tostr [$findDestination]] != "") do={ :set equalMACAddress (true); }
        }
        if ($equalMACAddress = false) do={
            :do {
                if ([ /interface bridge host get [ find mac-address=$ipArpMACAddress ] on-interface; ] != "") do={
                    :set ipArpNetwork ($ipArpInterface);
                    :set ipArpInterface ([ /interface bridge host get [ find mac-address=$ipArpMACAddress ] on-interface; ]);
                }
            } on-error={ }
            :set ($ipArpArray->$ipArpIndexArray) {$ipArpInterface;$ipArpMACAddress;$ipArpIP;$ipArpComment;$ipArpNetwork};
            :set ipArpIndexArray ($ipArpIndexArray + 1);
        }
    }
    :set ipArpIndexArray ($ipArpIndexArray - 1);

    # build new list
    :local newIndexArray 1;
    :local newArray {"";"";"";"";"";"";""};
    :set ($newArray->0) {"NUMBER";"INTERFACE";"HOST-NAME";"MAC-ADDRESS";"IP-ADDRESS";"NETWORK";"REMARK"};
    :set ($newArray->1) {"";"";"";"";"";"";""};
    :for i from=0 to=$interfaceIndexArray do={
        :for j from=0 to=$bridgeHostIndexArray do={
            :local findDestination [:find key=($bridgeHostArray->$j->0) in=($interfaceArray->$i)];
            if ([:tostr [$findDestination]] != "" && ($bridgeHostArray->$j->4) != ($bridgeHostArray->$j->0)) do={
                if (($bridgeHostArray->$j->2) = ($interfaceArray->$i->2)) do={
                    :set ($newArray->$newIndexArray) {$newIndexArray;($bridgeHostArray->$j->0);($bridgeHostArray->$j->1);($bridgeHostArray->$j->2);($bridgeHostArray->$j->3);($bridgeHostArray->$j->4);($interfaceArray->$i->3)}; 
                } else={
                    :set ($newArray->$newIndexArray) {$newIndexArray;($bridgeHostArray->$j->0);($bridgeHostArray->$j->1);($bridgeHostArray->$j->2);($bridgeHostArray->$j->3);($bridgeHostArray->$j->4);($bridgeHostArray->$j->5)}; 
                }
                :set newIndexArray ($newIndexArray + 1);
            }
        }
        :for j from=0 to=$ipArpIndexArray do={
            :local findDestination [:find key=($ipArpArray->$j->0) in=($interfaceArray->$i)];
            if ([:tostr [$findDestination]] != "") do={
                :set ($newArray->$newIndexArray) {$newIndexArray;($ipArpArray->$j->0);"";($ipArpArray->$j->1);($ipArpArray->$j->2);($ipArpArray->$j->4);($ipArpArray->$i->3)}; 
                :set newIndexArray ($newIndexArray + 1);
            }
        }
        :for j from=0 to=$ipAddressIndexArray do={
            :local findDestination [:find key=($interfaceArray->$i->0) in=($ipAddressArray->$j)];
            if ([:tostr [$findDestination]] != "") do={
                :set ($newArray->$newIndexArray) {$newIndexArray;($interfaceArray->$i->0);($interfaceArray->$i->1);($interfaceArray->$i->2);($ipAddressArray->$j->1);($ipAddressArray->$j->2);($interfaceArray->$i->3)}; 
                :set newIndexArray ($newIndexArray + 1);
            }
        }
    }
    :set newIndexArray ($newIndexArray - 1);

    # list output to terminal
    :local outMsgTrm;
    :local outMsgLog;
    :for i from=0 to=$newIndexArray do={
        :set outMsgTrm ($outMsgTrm."\r\n".($newArray->$i->0)." \t".($newArray->$i->1)." \t".($newArray->$i->2)." \t".($newArray->$i->4)." \t".($newArray->$i->3)." \t".($newArray->$i->5)." \t".($newArray->$i->6));
        :set outMsgLog ($outMsgLog."\r\n".($newArray->$i->0)." \t".($newArray->$i->1)." \t".($newArray->$i->2)." \t".($newArray->$i->4)." \t".($newArray->$i->3)." \t".($newArray->$i->5)." \t".($newArray->$i->6));
    }
    :put $outMsgTrm;
    :log warn $outMsgLog;
}

