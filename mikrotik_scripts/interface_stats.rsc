# A script to gather MikroTik interface data and send it to InfluxDB/Grafana
#
# Visit www.mikrotikscripting.com for more tips/info 

/import influx_exporter.rsc

:global DEBUG false;
:global PostToInflux;

:local DataStructure "";
# system identity (hostname)
:local Hostname [/system identity get name];

#######################
# Interface Stats
#######################

# get a list of all running interfaces
:local InterfaceList [/interface find where type="ether" and running];

# create variable to hold interface data
:local InterfaceData;

:foreach Interface in=$InterfaceList do={

    # get interface data & extract required values
    :local InterfaceDataArray [/interface monitor-traffic $Interface as-value once];
    :local InterfaceName ($InterfaceDataArray->"name");
    :local RxBitsPerSec ($InterfaceDataArray->"rx-bits-per-second");
    :local TxBitsPerSec ($InterfaceDataArray->"tx-bits-per-second");

    # create data entries for retrieved data
    :set DataStructure ($DataStructure . "\nrx_bps,hostname=$Hostname,category=interface,interface=$InterfaceName value=$RxBitsPerSec");
    :set DataStructure ($DataStructure . "\ntx_bps,hostname=$Hostname,category=interface,interface=$InterfaceName value=$TxBitsPerSec");

    if ($DEBUG) do={ 
        :put "Interface name: $InterfaceName";
        :put "$InterfaceName (rx_bps): $RxBitsPerSec";
        :put "$InterfaceName (tx_bps): $TxBitsPerSec";
    }

    :local EtherDataArray ([:interface ethernet print stats from=$Interface as-value]->0);
    :set InterfaceName ($EtherDataArray->"name");
    :local RxFcsError ($EtherDataArray->"rx-fcs-error");
    :local TxDrop ($EtherDataArray->"tx-drop");

    # create data entries for retrieved data
    :set DataStructure ($DataStructure . "\nrx_fcs_error,hostname=$Hostname,category=interface,interface=$InterfaceName value=$RxFcsError");
    :set DataStructure ($DataStructure . "\ntx_drop,hostname=$Hostname,category=interface,interface=$InterfaceName value=$TxDrop");

    if ($DEBUG) do={ 
    :put "Interface name: $InterfaceName";
    :put "$InterfaceName (rx fcs error): $RxFcsError";
    :put "$InterfaceName (tx_drop): $TxDrop";
    }

}

# post data to Influx
$PostToInflux $DataStructure $DEBUG;

# tidy up global vars
:set DEBUG;




