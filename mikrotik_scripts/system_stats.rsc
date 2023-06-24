/import influx_exporter.rsc

:global DEBUG false;
:global PostToInflux;

:local DataStructure "";
# system identity (hostname)
:local Hostname [/system identity get name];

#############################
# Get Mikrotik CPU Usage (%)
#############################
:local CpuLoad [/system resource get cpu-load];

if ($DEBUG) do={ :put "CPU Load: $CpuLoad"; }
:set DataStructure ("cpu_load,hostname=$Hostname,category=system value=$CpuLoad");

#############################
# Get Mikrotik Temperature
#############################
:local Temperature [/system health get temperature];

if ($DEBUG) do={ :put "Temperature: $Temperature"; }
:set DataStructure ($DataStructure . "\ntemperature,hostname=$Hostname,category=system value=$Temperature");

#############################
# Get Mikrotik Memory Stats
#############################
:local FreeMemory [/system resource get free-memory];
:local TotalMemory [/system resource get total-memory];
:local UsedMemory ($TotalMemory - $FreeMemory);

if ($DEBUG) do={ 
    :put "Free memory: $FreeMemory"; 
    :put "Total memory: $TotalMemory";
}

:set DataStructure ($DataStructure . "\nused_memory,hostname=$Hostname,category=system value=$UsedMemory");
:set DataStructure ($DataStructure . "\ntotal_memory,hostname=$Hostname,category=system value=$TotalMemory");

# post data to Influx
$PostToInflux $DataStructure $DEBUG;

# tidy up global vars
:set DEBUG;




