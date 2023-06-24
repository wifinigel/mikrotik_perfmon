# A module to post data to influxdb (v1.8 only - does not work with v2.x/v3.x)

:global PostToInflux do={

        :local InfluxHost "set_ip_here"; 
        :local InfluxPort "8086";
        :local InfluxUsername "mtik_agent";
        :local InfluxPassword "set_db_pwd_here";
        :local InfluxDatabase "mikrotik_dashboard"; 

        :local InfluxData $1;
        :local DebugSwitch $2;

        :local InfluxUrl ("http://$InfluxHost:$InfluxPort/write?db=$InfluxDatabase&u=$InfluxUsername&p=$InfluxPassword");

    if ( $DebugSwitch ) do={ 
        :put "Sending data to InfluxDB..."; 
        :put "Influx URL: $InfluxUrl";
        :put "Data: $InfluxData"
    }

    do { 
        /tool fetch \
        http-method=post \
        http-header-field="Content-Type: text/plain;" \
        http-data="$InfluxData" \
        url="$InfluxUrl" \
        mode=http \
        keep-result=no;
    } on-error={ 
        # if http post fails, log an error message & exit
        :local ErrorMessage "HTTP post failed in PostToInflux function (payload=$InfluxData).";
        :log error $ErrorMessage;
    };

}
