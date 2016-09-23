#include <stdio.h>
#include "TKN154.h"
#include "settings.h"

module testtknC
{
	uses {
		interface Boot;
		interface Leds;
		//
		interface MLME_ASSOCIATE;
		interface MLME_DISASSOCIATE;
		interface MLME_START;
		interface MLME_RESET;
		interface MLME_SET;
		interface MLME_GET;
		interface MLME_COMM_STATUS;
		interface IEEE154TxBeaconPayload;
		interface IEEE154Frame as DataFrame;
		interface Packet;
		interface MCPS_DATA;
	}
}

implementation
{
	bool result;
	ieee154_CapabilityInformation_t capinfo;
	ieee154_PANDescriptor_t PANdesc;
	message_t frame_msg;
	uint8_t *payload;

	void startApp();

	event void Boot.booted()
	{
		call MLME_RESET.request(TRUE);
	}

	event void MLME_RESET.confirm(ieee154_status_t status)
	{
		if (status == IEEE154_SUCCESS) {
			call MLME_SET.macShortAddress(COORDINATOR_ADDRESS);
			call MLME_SET.macAssociationPermit(TRUE);
			call MLME_SET.phyTransmitPower(TX_POWER);
			call Leds.led0On();
			call MLME_START.request(PAN_ID, // PANId
									RADIO_CHANNEL,    // LogicalChannel
									0,                // ChannelPage,
									0,                // StartTime,
									BEACON_ORDER,     // BeaconOrder
									SUPERFRAME_ORDER, // SuperframeOrder
									TRUE,             // PANCoordinator
									FALSE,            // BatteryLifeExtension
									FALSE,            // CoordRealignment
									0,                // no realignment security
									0                 // no beacon security
									);
		}
	}
	
	event void MLME_START.confirm(ieee154_status_t status) {}
	event void IEEE154TxBeaconPayload.aboutToTransmit() {}
	event void IEEE154TxBeaconPayload.setBeaconPayloadDone(void *beaconPayload, uint8_t length) {}
	event void IEEE154TxBeaconPayload.modifyBeaconPayloadDone(uint8_t offset, void *buffer, uint8_t bufferLength) {}
	event void IEEE154TxBeaconPayload.beaconTransmitted() {}
	event void MCPS_DATA.confirm(message_t *msg, uint8_t msduHandle, ieee154_status_t status, uint32_t timestamp) {}
	
	event message_t *MCPS_DATA.indication(message_t *frame)
	{
		uint8_t code;
		uint8_t KEY = 0x55;

		uint8_t *p = call Packet.getPayload(frame, 1);
		code = p[0] ^ KEY;
		call Leds.set(code);		
		return frame;
	}

	event void MLME_COMM_STATUS.indication(uint16_t PANId, uint8_t SrcAddrMode,
											ieee154_address_t SrcAddr,
											uint8_t DstAddrMode,
											ieee154_address_t DstAddr,
											ieee154_status_t status,
											ieee154_security_t *security
											)
	{}

	event void MLME_ASSOCIATE.indication(uint64_t DeviceAddress,
										ieee154_CapabilityInformation_t CapabilityInformation,
										ieee154_security_t *security
										)
	{
		call MLME_ASSOCIATE.response(DeviceAddress, 111, IEEE154_ASSOCIATION_SUCCESSFUL, 0);
	}

	event void MLME_ASSOCIATE.confirm(uint16_t AssocShortAddress,
										uint8_t status,
										ieee154_security_t *security
										)
	{}

	event void MLME_DISASSOCIATE.confirm(ieee154_status_t status, uint8_t DeviceAddrMode, uint16_t DevicePANID, ieee154_address_t DeviceAddress)
	{}

	event void MLME_DISASSOCIATE.indication(uint64_t DeviceAddress,
											ieee154_disassociation_reason_t DisassociateReason,
											ieee154_security_t *security
											)
	{}
}
