configuration testtkn_cfg {}
implementation
{
	components testtknC as App;

	components MainC, LedsC;
	MainC.Boot <- App;
	App.Leds -> LedsC;
	
	components Ieee802154BeaconEnabledC as TKN;
	App.MLME_ASSOCIATE -> TKN;
	App.MLME_DISASSOCIATE -> TKN;
	App.MLME_RESET -> TKN;
	App.MLME_SET -> TKN;
	App.MLME_GET -> TKN;
	App.MLME_COMM_STATUS -> TKN;
	App.MLME_START -> TKN;
	App.IEEE154TxBeaconPayload -> TKN;

	App.DataFrame -> TKN;
	App.Packet -> TKN;
	App.MCPS_DATA -> TKN;
}
