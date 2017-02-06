###############################################################################
# 
# Developed with Kate
#
#  (c) 2016-2017 Copyright: Marko Oldenburg (leongaultier at gmail dot com)
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id$
#
###############################################################################


package main;

use strict;
use warnings;
use POSIX;

use JSON;
use Blocking;
use SetExtensions;


my $version = "1.0.2";




my %playbulbModels = (
        BTL300_v5       => {'aColor' => '0x16'  ,'aEffect' => '0x14'    ,'aBattery' => '0x1f'   ,'aDevicename' => '0x3'},   # Candle Firmware 5
        BTL300_v6       => {'aColor' => '0x19'  ,'aEffect' => '0x17'    ,'aBattery' => '0x22'   ,'aDevicename' => '0x3'},   # Candle Firmware 6
        BTL201_v2       => {'aColor' => '0x1b'  ,'aEffect' => '0x19'    ,'aBattery' => 'none'   ,'aDevicename' => 'none'},  # Smart
        BTL201M_V16     => {'aColor' => '0x25'  ,'aEffect' => '0x23'    ,'aBattery' => 'none'   ,'aDevicename' => '0x7'},   # Smart (1/2017)
        BTL505_v1       => {'aColor' => '0x23'  ,'aEffect' => '0x21'    ,'aBattery' => 'none'   ,'aDevicename' => '0x29'},  # Stripe
        BTL400M_v18     => {'aColor' => '0x23'  ,'aEffect' => '0x21'    ,'aBattery' => '0x2e'   ,'aDevicename' => '0x7'},   # Garden
        BTL100C_v10     => {'aColor' => '0x1b'  ,'aEffect' => '0x19'    ,'aBattery' => 'none'   ,'aDevicename' => 'none'},  # Color LED
    );

my %effects = ( 
        'Flash'         =>  '00',
        'Pulse'         =>  '01',
        'RainbowJump'   =>  '02',
        'RainbowFade'   =>  '03',
        'Candle'        =>  '04',
        'none'          =>  'FF',
    );
    
my %effectsHex = (
        '00'            =>  'Flash',
        '01'            =>  'Pulse',
        '02'            =>  'RainbowJump',
        '03'            =>  'RainbowFade',
        '04'            =>  'Candle',
        'ff'            =>  'none',
    );


sub PLAYBULB_Initialize($);
sub PLAYBULB_Define($$);
sub PLAYBULB_Undef($$);
sub PLAYBULB_Attr(@);
sub PLAYBULB_firstRun($);
sub PLAYBULB_Set($$@);
sub PLAYBULB_Run($$$);
sub PLAYBULB_BlockingRun($);
sub PLAYBULB_gattCharWrite($$$$$$$$$);
sub PLAYBULB_gattCharRead($$$);
sub PLAYBULB_readBattery($$);
sub PLAYBULB_stateOnOff($$);
sub PLAYBULB_readDevicename($$);
sub PLAYBULB_writeDevicename($$$);
sub PLAYBULB_forRun_encodeJSON($$$$$$$$$$$$$);
sub PLAYBULB_forDone_encodeJSON($$$$$$$);
sub PLAYBULB_BlockingDone($);
sub PLAYBULB_BlockingAborted($);




sub PLAYBULB_Initialize($) {

    my ($hash) = @_;

    $hash->{SetFn}	    = "PLAYBULB_Set";
    $hash->{DefFn}	    = "PLAYBULB_Define";
    $hash->{UndefFn}	= "PLAYBULB_Undef";
    $hash->{AttrFn}	    = "PLAYBULB_Attr";
    $hash->{AttrList} 	= "model:BTL300_v5,BTL300_v6,BTL201_v2,BTL201M_V16,BTL505_v1,BTL400M_v18,BTL100C_v10 ".
                            $readingFnAttributes;



    foreach my $d(sort keys %{$modules{PLAYBULB}{defptr}}) {
        my $hash = $modules{PLAYBULB}{defptr}{$d};
        $hash->{VERSION} 	= $version;
    }
}

sub PLAYBULB_Define($$) {

    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    
    return "too few parameters: define <name> PLAYBULB <BTMAC>" if( @a != 3 );
    

    my $name    	= $a[0];
    my $mac     	= $a[2];
    
    $hash->{BTMAC} 	= $mac;
    $hash->{VERSION} 	= $version;
    
    
    $modules{PLAYBULB}{defptr}{$hash->{BTMAC}} = $hash;
    readingsSingleUpdate ($hash,"state","Unknown", 0);
    $attr{$name}{room}          = "PLAYBULB" if( !defined($attr{$name}{room}) );
    $attr{$name}{devStateIcon}  = "unreachable:light_question" if( !defined($attr{$name}{devStateIcon}) );
    $attr{$name}{webCmd}        = "rgb:rgb FF0000:rgb 00FF00:rgb 0000FF:rgb FFFFFF:rgb F7FF00:rgb 00FFFF:rgb F700FF:effect" if( !defined($attr{$name}{webCmd}) );
    
    $hash->{helper}{effect}     = ReadingsVal($name,"effect","none"); 
    $hash->{helper}{onoff}      = ReadingsVal($name,"onoff",0); 
    $hash->{helper}{rgb}        = ReadingsVal($name,"rgb","ff0000"); 
    $hash->{helper}{sat}        = ReadingsVal($name,"sat",0); 
    $hash->{helper}{speed}      = ReadingsVal($name,"speed",120);
    
    
    if( $init_done ) {
    
        PLAYBULB_firstRun($hash);
        
    } else {
    
        InternalTimer( gettimeofday()+30, "PLAYBULB_firstRun", $hash, 1 ) ;
    }
    
    
    $modules{PLAYBULB}{defptr}{$hash->{BTMAC}} = $hash;
    return undef;
}

sub PLAYBULB_Undef($$) {

    my ( $hash, $arg ) = @_;
    
    my $mac = $hash->{BTMAC};
    my $name = $hash->{NAME};
    
    
    Log3 $name, 3, "PLAYBULB ($name) - undefined";
    delete($modules{PLAYBULB}{defptr}{$mac});

    return undef;
}

sub PLAYBULB_Attr(@) {

    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};
    
    my $orig = $attrVal;

    if( $attrName eq "model" ) {
        if( $cmd eq "set" ) {
            
            PLAYBULB($hash,"statusRequest",undef) if( $init_done );
        }
    }
}

sub PLAYBULB_firstRun($) {

    my ($hash)      = @_;
    my $name        = $hash->{NAME};
    
    RemoveInternalTimer($hash);
    
    PLAYBULB_Run($hash,"statusRequest",undef);
}

sub PLAYBULB_Set($$@) {
    
    my ($hash, $name, @aa) = @_;
    my ($cmd, $arg) = @aa;
    my $action;

    if( $cmd eq 'on' ) {
        $action = "onoff";
        $arg    = 1;
        
    } elsif( $cmd eq 'off' ) {
        $action = "onoff";
        $arg    = 0;

    } elsif( $cmd eq 'effect' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'rgb' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'sat' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'speed' ) {
        $action = $cmd;
    
    } elsif( $cmd eq 'color' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'deviceName' ) {
        my $wordlenght = length($arg);
        return "to many character for Devicename" if($wordlenght > 20 );
        $action = $cmd;
        
    } elsif( $cmd eq 'statusRequest' ) {
        $action = $cmd;
        $arg    = undef;
    
    } else {
        my $list = "on:noArg off:noArg rgb:colorpicker,RGB sat:slider,0,5,255 effect:Flash,Pulse,RainbowJump,RainbowFade,Candle,none speed:slider,170,50,20 color:on,off statusRequest:noArg ";
        $list .= "deviceName " if( $attr{$name}{model} ne "BTL400M_v18" or $attr{$name}{model} ne "BTL100C_v10" );
        return SetExtensions($hash, $list, $name, $cmd, $arg);
    }
    
    PLAYBULB_Run($hash,$action,$arg);
    
    return undef;
}

sub PLAYBULB_Run($$$) {

    my ( $hash, $cmd, $arg ) = @_;
    
    my $name    = $hash->{NAME};
    
    unless( defined($attr{$name}{model}) ) {
        readingsSingleUpdate($hash,'state','set attribut model',1);
        return;
    }
    
    my $mac     = $hash->{BTMAC};
    my $dname;
    $hash->{helper}{$cmd}           = $arg if( $cmd ne "deviceName" );
    $hash->{helper}{setDeviceName}  = 1 if( $cmd eq "deviceName" );
    
    my $rgb         =   $hash->{helper}{rgb};
    my $sat         =   sprintf("%02x", $hash->{helper}{sat});
    my $effect      =   $hash->{helper}{effect};
    my $speed       =   sprintf("%02x", $hash->{helper}{speed});
    my $stateOnoff  =   $hash->{helper}{onoff};
    my $stateEffect =   ReadingsVal($name,"effect","none");
    my $ac          =   $playbulbModels{$attr{$name}{model}}{aColor};
    my $ae          =   $playbulbModels{$attr{$name}{model}}{aEffect};
    my $ab          =   $playbulbModels{$attr{$name}{model}}{aBattery};
    my $adname      =   $playbulbModels{$attr{$name}{model}}{aDevicename};
    $dname          =   $arg if( $cmd eq "deviceName" );
    
    if( $cmd eq "color" and $arg eq "off") {
        $rgb    = "000000";
        $sat    = "FF";
    }



    BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));
        
    my $response_encode = PLAYBULB_forRun_encodeJSON($cmd,$mac,$stateOnoff,$sat,$rgb,$effect,$speed,$stateEffect,$ac,$ae,$ab,$adname,$dname);
        
    $hash->{helper}{RUNNING_PID} = BlockingCall("PLAYBULB_BlockingRun", $name."|".$response_encode, "PLAYBULB_BlockingDone", 5, "PLAYBULB_BlockingAborted", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
    Log3 $name, 4, "(Sub PLAYBULB - $name) - Call BlockingRun";
}

sub PLAYBULB_BlockingRun($) {

    my ($string)        = @_;
    my ($name,$data)    = split("\\|", $string);
    my $data_json       = decode_json($data);
    
    my $mac             = $data_json->{mac};
    my $stateOnoff      = $data_json->{stateOnoff};
    my $sat             = $data_json->{sat};
    my $rgb             = $data_json->{rgb};
    my $effect          = $data_json->{effect};
    my $speed           = $data_json->{speed};
    my $stateEffect     = $data_json->{stateEffect};
    my $ac              = $data_json->{ac};
    my $ae              = $data_json->{ae};
    my $ab              = $data_json->{ab};
    my $cmd             = $data_json->{cmd};
    my $adname          = $data_json->{adname};
    my $dname           = $data_json->{dname};
    my $blevel          = 1000;
    my $cc;
    my $ec;
    
    my $response_encode;
    
    Log3 $name, 4, "(Sub PLAYBULB_Run - $name) - Running nonBlocking";



    ##### Abruf des aktuellen Status
    #### das c vor den bekannten Variablen steht für current
    my ($ccc,$cec,$csat,$crgb,$ceffect,$cspeed)  = PLAYBULB_gattCharRead($mac,$ac,$ae);

    if( defined($ccc) and defined($cec) ) {

        
        ### Regeln für die aktuellen Values
        if( $cmd eq "statusRequest" ) {
        
            ###### Batteriestatus einlesen    
            $blevel = PLAYBULB_readBattery($mac,$ab) if( $ab ne "none" );
            
            ###### Status ob An oder Aus
            $stateOnoff = PLAYBULB_stateOnOff($ccc,$cec);
            
            ###### Devicename ermitteln #######
            my $dname = PLAYBULB_readDevicename($mac,$adname) if( $adname ne "none" );
            
            
            Log3 $name, 4, "(Sub PLAYBULB_Run StatusRequest - $name) - Rückgabe an Auswertungsprogramm beginnt";
            $response_encode = PLAYBULB_forDone_encodeJSON($blevel,$stateOnoff,$csat,$crgb,$ceffect,$cspeed,$dname);
            return "$name|$response_encode";
        }
        
        $stateEffect = "none" if( $ceffect eq "ff" );


        ##### Schreiben der neuen Char values
        PLAYBULB_gattCharWrite($sat,$rgb,$effect,$speed,$stateEffect,$stateOnoff,$mac,$ac,$ae) if( !defined($dname) );
        PLAYBULB_writeDevicename($mac,$adname,$dname) if( defined($dname) );
        
    
        ##### Statusabruf nach dem schreiben der neuen Char Values
        ($cc,$ec,$sat,$rgb,$effect,$speed)  = PLAYBULB_gattCharRead($mac,$ac,$ae) if( !defined($dname) );
        $dname = PLAYBULB_readDevicename($mac,$adname) if( defined($dname) and $adname ne "none" );


        $stateOnoff = PLAYBULB_stateOnOff($cc,$ec) if( !defined($dname) );
    
        ###### Batteriestatus einlesen
        $blevel = PLAYBULB_readBattery($mac,$ab) if( $ab ne "none" and !defined($dname) );
        
        
        Log3 $name, 4, "(Sub PLAYBULB_Run - $name) - Rückgabe an Auswertungsprogramm beginnt";
        $response_encode = PLAYBULB_forDone_encodeJSON($blevel,$stateOnoff,$sat,$rgb,$effect,$speed,undef) if( !defined($dname) );
        $response_encode = PLAYBULB_forDone_encodeJSON(undef,undef,undef,undef,undef,undef,$dname) if( defined($dname) );
        return "$name|$response_encode";
    }


    Log3 $name, 4, "(Sub PLAYBULB_Run - $name) - Rückgabe an Auswertungsprogramm beginnt";

    return "$name|err"
    unless( defined($cc) and defined($ec) );
}

sub PLAYBULB_gattCharWrite($$$$$$$$$) {

    my ($sat,$rgb,$effect,$speed,$stateEffect,$stateOnoff,$mac,$ac,$ae)  = @_;
    
    my $loop = 0;
    while ( (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop = 0) or (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop < 5) ) {
        #printf "\n(Sub PLAYBULB_Run) - gatttool noch aktiv, wait 0.5s for new check\n";
        sleep 0.5;
        $loop++;
    }
    
    
    
    $speed = "01" if( $effect eq "Candle" );
    
    if( $stateOnoff == 0 ) {
        qx(gatttool -b $mac --char-write -a $ac -n 00000000);
        qx(gatttool -b $mac --char-write -a $ae -n 00000000ff000000);
    } else {
        qx(gatttool -b $mac --char-write -a $ac -n ${sat}${rgb}) if( $stateEffect eq "none" and $effect eq "none" );
        qx(gatttool -b $mac --char-write -a $ae -n ${sat}${rgb}${effects{$effect}}00${speed}00) if( $stateEffect ne "none" or $effect ne "none" );
    }
}

sub PLAYBULB_gattCharRead($$$) {

    my ($mac,$ac,$ae)       = @_;

    my $loop = 0;
    while ( (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop = 0) or (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop < 5) ) {
        #printf "\n(Sub PLAYBULB_Run) - gatttool noch aktiv, wait 0.5s for new check\n";
        sleep 0.5;
        $loop++;
    }
    
    my @cc          = split(": ",qx(gatttool -b $mac --char-read -a $ac));
    my @ec          = split(": ",qx(gatttool -b $mac --char-read -a $ae));
    
    return (undef,undef,undef,undef,undef,undef)
    unless( defined($cc[1]) and defined($ec[1]) );
    
    
    my $cc          = join("",split(" ",$cc[1]));
    my $ec          = substr(join("",split(" ",$ec[1])),0,8);

    my $sat            = hex("0x".substr(join("",split(" ",$ec[1])),0,2));
    my $rgb            = substr(join("",split(" ",$ec[1])),2,6);
    my $effect         = $effectsHex{substr(join("",split(" ",$ec[1])),8,2)};
    my $speed          = hex("0x".substr(join("",split(" ",$ec[1])),12,2));


    if( $effect eq "none" ) {
        $sat            = hex("0x".substr(join("",split(" ",$cc[1])),0,2));
        $rgb            = substr(join("",split(" ",$cc[1])),2,6);
    }
    
    return ($cc,$ec,$sat,$rgb,$effect,$speed);
}

sub PLAYBULB_readBattery($$) {

    my ($mac,$ab)   = @_;
    
    chomp(my @blevel  = split(": ",qx(gatttool -b $mac --char-read -a $ab)));
    my $blevel = substr(join("",split(" ",$blevel[1])),0,2);

    return hex($blevel);
}

sub PLAYBULB_stateOnOff($$) {

    my ($cc,$ec)    = @_;
    my $state;
    
    if( $cc eq "00000000" and $ec eq "00000000" ) {
        $state = "0";
    } else {
        $state = "1";
    }
    
    return $state;
}

sub PLAYBULB_readDevicename($$) {

    my ($mac,$adname)       = @_;

    chomp(my @dname  = split(": ",qx(gatttool -b $mac --char-read -a $adname)));
    my $dname = join("",split(" ",$dname[1]));
    
    return pack('H*', $dname);
}

sub PLAYBULB_writeDevicename($$$) {

    my ($mac,$adname,$dname)       = @_;

    my $hexDname = unpack("H*", $dname);
    qx(gatttool -b $mac --char-write-req -a $adname -n $hexDname);
}

sub PLAYBULB_forRun_encodeJSON($$$$$$$$$$$$$) {

    my ($cmd,$mac,$stateOnoff,$sat,$rgb,$effect,$speed,$stateEffect,$ac,$ae,$ab,$adname,$dname) = @_;

    my %data = (
        'cmd'           => $cmd,
        'mac'           => $mac,
        'stateOnoff'    => $stateOnoff,
        'sat'           => $sat,
        'rgb'           => $rgb,
        'effect'        => $effect,
        'speed'         => $speed,
        'stateEffect'   => $stateEffect,
        'ac'            => $ac,
        'ae'            => $ae,
        'ab'            => $ab,
        'adname'        => $adname,
        'dname'         => $dname
    );
    
    return encode_json \%data;
}

sub PLAYBULB_forDone_encodeJSON($$$$$$$) {

    my ($blevel,$stateOnoff,$sat,$rgb,$effect,$speed,$dname)        = @_;

    my %response = (
        'blevel'     => $blevel,
        'stateOnoff' => $stateOnoff,
        'sat'        => $sat,
        'rgb'        => $rgb,
        'effect'     => $effect,
        'speed'      => $speed,
        'dname'      => $dname
    );
    
    return encode_json \%response;
}

sub PLAYBULB_BlockingDone($) {

    my ($string) = @_;
    my ($name,$response)       = split("\\|",$string);
    my $hash    = $defs{$name};
    my $state;
    my $color;
    
    
    
    delete($hash->{helper}{RUNNING_PID});
    
    Log3 $name, 3, "(Sub PLAYBULB_Done - $name) - Der Helper ist disabled. Daher wird hier abgebrochen" if($hash->{helper}{DISABLED});
    return if($hash->{helper}{DISABLED});
    
    
    if( $response eq "err" ) {
        readingsSingleUpdate($hash,"state","unreachable", 1);
        return undef;
    }
    
    my $response_json = decode_json($response);
    
    
    if( !defined($hash->{helper}{setDeviceName}) ) {
        if( $response_json->{stateOnoff} == 1 ) { $state = "on" } else { $state = "off" } ;
    
    
        if( ($response_json->{sat} eq "255" and $response_json->{rgb} eq "000000") or 
            ($response_json->{sat} eq "0" and $response_json->{rgb} eq "ffffff") ) {
            $color = "off"; } else { $color = "on"; }
    }
    
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "color", "$color") if( !defined($hash->{helper}{setDeviceName}) );
    readingsBulkUpdate($hash, "battery", $response_json->{blevel}) if( $response_json->{blevel} != 1000 and !defined($hash->{helper}{setDeviceName}) );
    readingsBulkUpdate($hash, "deviceName", $response_json->{dname});
    readingsBulkUpdate($hash, "onoff", $response_json->{stateOnoff});
    readingsBulkUpdate($hash, "sat", $response_json->{sat}) if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    readingsBulkUpdate($hash, "rgb", $response_json->{rgb}) if( $response_json->{stateOnoff} != 0 and $color ne "off" and !defined($hash->{helper}{setDeviceName}) );
    readingsBulkUpdate($hash, "effect", $response_json->{effect});
    readingsBulkUpdate($hash, "speed", $response_json->{speed});
    readingsBulkUpdate($hash, "state", $state);
    readingsEndUpdate($hash,1);

    $hash->{helper}{onoff}  = $response_json->{stateOnoff};
    $hash->{helper}{sat}    = $response_json->{sat} if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    $hash->{helper}{rgb}    = $response_json->{rgb} if( $response_json->{stateOnoff} != 0 and $color ne "off" and !defined($hash->{helper}{setDeviceName}) );
    $hash->{helper}{effect} = $response_json->{effect};
    $hash->{helper}{speed}  = $response_json->{speed};
    
    delete $hash->{helper}{setDeviceName} if( defined($hash->{helper}{setDeviceName}) );
    
    
    Log3 $name, 4, "(Sub PLAYBULB_Done - $name) - Abschluss!";
}

sub PLAYBULB_BlockingAborted($) {

    my ($hash) = @_;
    my $name = $hash->{NAME};

    delete($hash->{helper}{RUNNING_PID});
    readingsSingleUpdate($hash,"state","unreachable", 1);
    Log3 $name, 4, "($name) - The BlockingCall Process terminated unexpectedly. Timedout";
}











1;








=pod
=item device
=item summary       Modul to control MiPow Playbulb products
=item summary_DE    Modul zum steuern der MiPow Playbulb Produkte

=begin html

=end html

=begin html_DE

<a name="PLAYBULB"></a>
<h3>MiPow Playbulb</h3>
<ul>
  <u><b>MiPow Playbulb - Zum steuern von MiPow Playbulb Produkten</b></u>
  <br>
  Mit diesem Modul ist es möglich die MiPow Playbulb Produkte über FHEM zu steuern</br>
  Voraussetzung hierfür ist ein BT LE 4.0 Empfänger/Sender (USB Stick), sowie die Programme gatttool und hcitool  (apt-get install bluez)</br>
  
  <br><br>
  <a name="XiaomiFlowerSensdefine"></a>
  <b>Define</b>
  <ul><br>
    <code>define &lt;name&gt; XiaomiFlowerSens &lt;BT-MAC&gt;</code>
    <br><br>
    Example:
    <ul><br>
      <code>define Weihnachtskaktus XiaomiFlowerSens C4:7C:8D:62:42:6F</code><br>
    </ul>
    <br>
    This statement creates a XiaomiFlowerSens with the name Weihnachtskaktus and the Bluetooth Mac C4:7C:8D:62:42:6F.<br>
    After the device has been created, the current data of the Xiaomi Flower Monitor is automatically read from the device.
  </ul>
  <br><br>
  <a name="XiaomiFlowerSensreadings"></a>
  <b>Readings</b>
  <ul>
    <li>state - Status of the flower sensor or error message if any errors.</li>
    <li>battery - current battery state dependent on batteryLevel.</li>
    <li>batteryLevel - current battery level in percent.</li>
    <li>fertility - Values for the fertilizer content</li>
    <li>firmware - current device firmware</li>
    <li>lux - current light intensity</li>
    <li>moisture - current moisture content</li>
    <li>temperature - current temperature</li>
  </ul>
  <br><br>
  <a name="XiaomiFlowerSensset"></a>
  <b>Set</b>
  <ul>
    <li>statusRequest - retrieves the current state of the Xiaomi Flower Monitor.</li>
    <br>
  </ul>
  <br><br>
  <a name="NUKIDeviceattribut"></a>
  <b>Attributes</b>
  <ul>
    <li>disable - disables the Nuki device</li>
    <li>interval - interval in seconds for statusRequest</li>
    <br>
  </ul>
</ul>

=end html_DE

=cut
