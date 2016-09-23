configuration testtkn_cfg {}
implementation
{
	components testtknC as App;

	components MainC, LedsC;
	MainC.Boot <- App;
	App.Leds -> LedsC;
	
	components Ieee802154BeaconEnabledC as TKN;
	App.MLME_RESET -> TKN;
	App.MLME_SET -> TKN;
	App.MLME_GET -> TKN;
	App.MLME_SCAN -> TKN;
	App.MLME_SYNC -> TKN;
	App.MLME_BEACON_NOTIFY -> TKN;
	App.MLME_SYNC_LOSS -> TKN;
	App.MLME_ASSOCIATE -> TKN;
	App.MLME_DISASSOCIATE -> TKN;
	App.MLME_COMM_STATUS -> TKN;

	App.BeaconFrame -> TKN;
	App.DataFrame -> TKN;
	App.Packet -> TKN;
	App.MCPS_DATA -> TKN;

	components new TimerMilliC() as TimerMilli;
	App.BlinkTimer -> TimerMilli;

	components SerialPrintfC;
}
