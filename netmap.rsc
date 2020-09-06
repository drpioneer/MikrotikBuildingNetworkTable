# Script for building a network table
# https://forummikrotik.ru/viewtopic.php?p=70575
# tested on ROS 6.47
# updated 2020/09/06

# interface list
:global interfaceIndexArray 0;
:global interfaceArray {"";"";"";"";""};
foreach interfaceIndex in=[ /interface find running=yes; ] do={
    :do {
        :local interfaceName ([ /interface get $interfaceIndex name; ]);
        :local interfaceComment ([:tostr [ /interface get $interfaceIndex comment; ]]);
        :local interfaceMAC ([:tostr [ /interface get $interfaceIndex mac-address; ]]);
        :local interfaceHost ([ /system resource get board-name; ]);
        :set ($interfaceArray->$interfaceIndexArray) {$interfaceName;$interfaceHost;$interfaceMAC;"";$interfaceComment};
        :set interfaceIndexArray ($interfaceIndexArray + 1);
    } on-error={ }
}
:set interfaceIndexArray ($interfaceIndexArray - 1);
    
# interface bridge host list
:global bridgeHostIndexArray 0;
:global bridgeHostArray {"";"";"";"";"";""};
foreach bridgeHost in=[ /interface bridge host find; ] do={
    :do {
        :local hostMAC ([ /interface bridge host get $bridgeHost mac-address; ]);
        :local hostBridge ([ /interface bridge host get $bridgeHost bridge; ]);
        :local hostInterface ([ /interface bridge host get $bridgeHost on-interface; ]);
        :local hostComment ("");
        :local hostName ("");
        :local hostIP ("");
        if ([ /interface bridge host get $bridgeHost local; ] = true) do={ 
            :set hostName ([ /system resource get board-name; ]);
            :set hostIP ([ /ip address get [ find interface=$hostBridge ] address; ]);
            :set hostIP ([:pick $hostIP 0 [:find $hostIP "/"]]);
        } else={
            :do {
                :set hostName ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] host-name; ]);
                :set hostIP ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] address; ]);
                :set hostComment ([ /ip dhcp-server lease get [ find mac-address=$hostMAC ] comment; ]);
            } on-error={ 
                :set hostName ([ /ip dhcp-server lease get [ find mac-address=$hostMAC dynamic=yes ] host-name; ]);
                :set hostIP ([ /ip dhcp-server lease get [ find mac-address=$hostMAC dynamic=yes ] address; ]);
            }
        }
        :set ($bridgeHostArray->$bridgeHostIndexArray) {$hostInterface;$hostName;$hostMAC;$hostIP;$hostBridge;$hostComment};
        :set bridgeHostIndexArray ($bridgeHostIndexArray + 1);
    } on-error={ }
}
:set bridgeHostIndexArray ($bridgeHostIndexArray - 1);
    
# ip address list
:global ipAddressIndexArray 0;
:global ipAddressArray {"";"";"";""};
foreach ipAddress in=([ /ip address find; ]) do={
    :do {
        :local ipAddressInterface ([ /ip address get $ipAddress interface; ]); 
        :local ipAddressIP ([ /ip address get $ipAddress address; ]); 
        :set ipAddressIP ([:pick $ipAddressIP 0 [:find $ipAddressIP "/"]]);
        :local ipAddressComment ([ /ip address get $ipAddress comment; ]); 
        :local ipAddressNetwork ([ /ip address get $ipAddress network; ]);
        if ([:tostr ($ipAddressIP)] != "") do={ 
            :set ($ipAddressArray->$ipAddressIndexArray) {$ipAddressInterface;$ipAddressIP;$ipAddressNetwork;$ipAddressComment};
            :set ipAddressIndexArray ($ipAddressIndexArray + 1);
        }
    } on-error={ } 
}
:set ipAddressIndexArray ($ipAddressIndexArray - 1);

# ip arp list
:global ipArpIndexArray 0;
:global ipArpArray {"";"";"";"";""}; 
foreach ipArp in=([ /ip arp find; ]) do={
    :do {
        :local ipArpInterface ([ /ip arp get $ipArp interface; ]); 
        :local ipArpIP ([ /ip arp get $ipArp address; ]); 
        :local ipArpComment ([ /ip arp get $ipArp comment; ]); 
        :local ipArpMACAddress ([ /ip arp get $ipArp mac-address; ]);
        :set ($ipArpArray->$ipArpIndexArray) {$ipArpInterface;"ARP";$ipArpMACAddress;$ipArpIP;$ipArpComment};
        :set ipArpIndexArray ($ipArpIndexArray + 1);
    } on-error={ } 
}
:set ipArpIndexArray ($ipArpIndexArray - 1);

# ip dhcp list
:global ipDhcpIndexArray 0;
:global ipDhcpArray {"";"";"";"";""}; 
foreach ipDhcp in=([ /ip dhcp-server lease find; ]) do={
    :do {
        :local ipDhcpName ([ /ip dhcp-server lease get $ipDhcp host-name; ]); 
        :local ipDhcpIP ([ /ip dhcp-server lease get $ipDhcp address; ]); 
        :local ipDhcpComment ([ /ip dhcp-server lease get $ipDhcp comment; ]); 
        :local ipDhcpMAC ([ /ip dhcp-server lease get $ipDhcp mac-address; ]);
        :set ($ipDhcpArray->$ipDhcpIndexArray) {"DHCP";$ipDhcpName;$ipDhcpMAC;$ipDhcpIP;$ipDhcpComment};
        :set ipDhcpIndexArray ($ipDhcpIndexArray + 1);
    } on-error={ } 
}
:set ipDhcpIndexArray ($ipDhcpIndexArray - 1);
    
# ip route list
:global ipRoutesIndexArray 0;
:global ipRoutesArray {"";"";"";"";""}; 
foreach ipRoutes in=([ /ip route find active=yes distance=0;]) do={
    :do {
        :local ipRouteName ([ /ip route get $ipRoutes gateway; ]); 
        :local ipRouteIP ([ /ip route get $ipRoutes pref-src; ]); 
        :local ipRouteComment ([ /ip route get $ipRoutes comment; ]); 
        :local ipRouteDstAddr ([ /ip route get $ipRoutes dst-address; ]);
        :set ipRouteDstAddr ([:pick $ipRouteDstAddr 0 [:find $ipRouteDstAddr "/"]]);
        :set ($ipRoutesArray->$ipRoutesIndexArray) {$ipRouteName;"ROUTE";$ipRouteDstAddr;$ipRouteIP;$ipRouteComment};
        :set ipRoutesIndexArray ($ipRoutesIndexArray + 1);
    } on-error={ } 
}
:set ipRoutesIndexArray ($ipRoutesIndexArray - 1);

# build new list
:global n 2;
:global newArray {"";"";"";"";"";"";""};
:set ($newArray->0) {"NUMBER";"INTERFACE";"HOST NAME";"MAC ADDRESS";"IP ADDRESS";"BRIDGE";"COMMENT"};
:set ($newArray->1) {"";"";"";"";"";"";""};
for i from=0 to=$interfaceIndexArray do={
    for j from=0 to=$bridgeHostIndexArray do={
        :local findDestination [:find key=($bridgeHostArray->$j->0) in=($interfaceArray->$i)];
        if ([:tostr [$findDestination]] != "" && ($bridgeHostArray->$j->4) != ($bridgeHostArray->$j->0)) do={
            if (($bridgeHostArray->$j->2) = ($interfaceArray->$i->2)) do={
                :set ($newArray->$n) {$n-1;($bridgeHostArray->$j->0);($bridgeHostArray->$j->1);($bridgeHostArray->$j->2);($bridgeHostArray->$j->3);($bridgeHostArray->$j->4);($interfaceArray->$i->4)}; 
            } else={
                :set ($newArray->$n) {$n-1;($bridgeHostArray->$j->0);($bridgeHostArray->$j->1);($bridgeHostArray->$j->2);($bridgeHostArray->$j->3);($bridgeHostArray->$j->4);($bridgeHostArray->$j->5)}; 
            }
            :set n ($n + 1);
        }
    }
    for j from=0 to=$ipAddressIndexArray do={
        :local findDestination [:find key=($interfaceArray->$i->0) in=($ipAddressArray->$j)];
        if ([:tostr [$findDestination]] != "") do={
            :set ($newArray->$n) {$n-1;($interfaceArray->$i->0);($interfaceArray->$i->1);($interfaceArray->$i->2);($ipAddressArray->$j->1);($ipAddressArray->$j->2);($interfaceArray->$i->4)}; 
            :set n ($n + 1);
        }
    }
}
:set n ($n - 1);

# list output to terminal
for i from=0 to=$n do={
    :set ($newArray->$i->0) ([:pick [:tostr [($newArray->$i->0 . "                         ")]] 0  6 ]);
    :set ($newArray->$i->1) ([:pick [:tostr [($newArray->$i->1 . "                         ")]] 0 21 ]);
    :set ($newArray->$i->2) ([:pick [:tostr [($newArray->$i->2 . "                         ")]] 0 25 ]);
    :set ($newArray->$i->3) ([:pick [:tostr [($newArray->$i->3 . "                         ")]] 0 19 ]);
    :set ($newArray->$i->4) ([:pick [:tostr [($newArray->$i->4 . "                         ")]] 0 17 ]);
    :set ($newArray->$i->5) ([:pick [:tostr [($newArray->$i->5 . "                         ")]] 0 17 ]);
    :set ($newArray->$i->6) ([:pick [:tostr [($newArray->$i->6 . "                         ")]] 0 25 ]);
    :put (($newArray->$i->0)." ".($newArray->$i->1)." ".($newArray->$i->2)." ".($newArray->$i->3)." ".($newArray->$i->4)." ".($newArray->$i->5)." ".($newArray->$i->6));
}
