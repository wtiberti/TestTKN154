#include <stdio.h>
#include "TKN154.h"
#include "settings.h"

module testtknC
{
	uses {
		interface Boot;
		interface Leds;
		//
		interface MLME_RESET;
		interface MLME_SET;
		interface MLME_GET;
		interface MLME_SCAN;
		interface MLME_SYNC;
		interface MLME_ASSOCIATE;
		interface MLME_DISASSOCIATE;
		interface MLME_COMM_STATUS;
		interface MLME_BEACON_NOTIFY;
		interface MLME_SYNC_LOSS;
		//
		interface IEEE154BeaconFrame as BeaconFrame;
		interface IEEE154Frame as DataFrame;
		interface Packet;
		interface MCPS_DATA;
		//
		interface Timer<TMilli> as BlinkTimer;
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
	void cipherMessage(uint8_t *p, size_t size);

	event void Boot.booted()
	{
		printf("Booted. Retrieving information\r\n");
		capinfo.AlternatePANCoordinator = 0;
		capinfo.DeviceType = 0;
		capinfo.PowerSource = 0;
		capinfo.ReceiverOnWhenIdle = 0;
		capinfo.Reserved = 0;
		capinfo.SecurityCapability = 0;
		capinfo.AllocateAddress = 1;

		printf("Done. Filling frame with basic informations...\r\n");
		payload = call Packet.getPayload(&frame_msg, sizeof(uint8_t)*1);
		// warning - assuming length<max
		payload[0] = 0;

		printf("Requesting RESET...\r\n");
		call MLME_RESET.request(TRUE);
	}

	event void MLME_RESET.confirm(ieee154_status_t status)
	{
		if (status == IEEE154_SUCCESS) {
			printf("RESET done; executing application...\r\n");
			startApp();
		}
	}

	void startApp()
	{
		ieee154_phyChannelsSupported_t channelBitmask;
		uint8_t scanDuration = BEACON_ORDER; 

		channelBitmask = ((uint32_t) 1) << RADIO_CHANNEL;

		call MLME_SET.macAutoRequest(FALSE);

		result = FALSE;
		printf("Scanning channel...\r\n");
		call MLME_SCAN.request(PASSIVE_SCAN,  // ScanType
								channelBitmask,// ScanChannels
								scanDuration,  // ScanDuration
								0x00,          // ChannelPage
								0,             // EnergyDetectListNumEntries
								NULL,          // EnergyDetectList
								0,             // PANDescriptorListNumEntries
								NULL,          // PANDescriptorList
								NULL);         // security
	}

	event void MLME_SCAN.confirm(ieee154_status_t status,
									uint8_t ScanType,
									uint8_t ChannelPage,
									uint32_t UnscannedChannels,
									uint8_t EnergyDetectListNumEntries,
									int8_t* EnergyDetectList,
									uint8_t PANDescriptorListNumEntries,
									ieee154_PANDescriptor_t *PANDescriptorList
									)
	{
		if (!result) {
			printf("SCAN failed. Retrying...\r\n");
			startApp();
		} else {
			call MLME_SET.macPANId(PANdesc.CoordPANId);
			call MLME_SET.macCoordShortAddress(PANdesc.CoordAddress.shortAddress);
			call MLME_SET.phyTransmitPower(TX_POWER);
			call MLME_SYNC.request(PANdesc.LogicalChannel, PANdesc.ChannelPage, TRUE);

			printf("Scan done. Setting addresses in frame...\r\n");
      		call DataFrame.setAddressingFields(&frame_msg,                
          		ADDR_MODE_SHORT_ADDRESS,	// SrcAddrMode,
          		ADDR_MODE_SHORT_ADDRESS,	// DstAddrMode,
          		PANdesc.CoordPANId,			// DstPANId,
          		&PANdesc.CoordAddress,		// DstAddr,
          		NULL);						// security

			printf("Ok. Requesting association...\r\n");
			call MLME_ASSOCIATE.request(PANdesc.LogicalChannel,
										PANdesc.ChannelPage,
										PANdesc.CoordAddrMode,
										PANdesc.CoordPANId,
										PANdesc.CoordAddress,
										capinfo,
										NULL // security
										);
		}
	}

	event void MLME_ASSOCIATE.confirm(uint16_t AssocShortAddress, uint8_t status, ieee154_security_t *security)
	{
		if ( status == IEEE154_SUCCESS ) {
			printf("Association completed!\r\n");
			call Leds.led0On();
			call BlinkTimer.startPeriodic(1000);
		} else {
			printf("Association FAILED. Retrying...\r\n");
			call MLME_ASSOCIATE.request(PANdesc.LogicalChannel,
										PANdesc.ChannelPage,
										PANdesc.CoordAddrMode,
										PANdesc.CoordPANId,
										PANdesc.CoordAddress,
										capinfo,
										NULL // security
										);
		}
	}

	event void BlinkTimer.fired()
	{
		call Leds.led1On();
		cipherMessage(payload, sizeof(uint8_t)*1);
		printf("Message 0x%X sent...\r\n", payload[0]);
		call MCPS_DATA.request(&frame_msg, sizeof(uint8_t)*1, 0, TX_OPTIONS_ACK);
	}

	void cipherMessage(uint8_t *p, size_t size)
	{
		uint8_t KEY = 0x55;
		int i;
		for (i=0; i<size; ++i)
			p[i] ^= KEY;
	}

	event void MCPS_DATA.confirm(message_t *msg, uint8_t msduHandle,
                          	ieee154_status_t status, uint32_t timestamp)
	{

		call Leds.led1Off();
		if (status != IEEE154_SUCCESS) {
			printf("Limit reached. Stopping timer & starting disassociation...\r\n");
			call BlinkTimer.stop();
			call MLME_DISASSOCIATE.request(PANdesc.CoordAddrMode,
											PANdesc.CoordPANId,
											PANdesc.CoordAddress,
											IEEE154_DEVICE_WISHES_TO_LEAVE,
											FALSE,
											NULL
											);
		} else {
			// decrypt
			printf("Ciphertext: %X\r\n", payload[0]);
			cipherMessage(payload, sizeof(uint8_t)*1);
			printf("Decrypted to: %X\r\n", payload[0]);
			payload[0]++;
		}
	}
	
	
	event message_t *MCPS_DATA.indication(message_t *frame)
	{
		return &frame_msg;
	}

	event message_t *MLME_BEACON_NOTIFY.indication(message_t* frame)
	{
		ieee154_phyCurrentPage_t page = call MLME_GET.phyCurrentPage();

		printf("BEACON found. Checking source...\r\n");
		if (!result) {
			if (call BeaconFrame.parsePANDescriptor(frame, RADIO_CHANNEL, page, &PANdesc) == SUCCESS) {
				if (PANdesc.CoordAddrMode == ADDR_MODE_SHORT_ADDRESS &&
						PANdesc.CoordPANId == PAN_ID &&
						PANdesc.CoordAddress.shortAddress == COORDINATOR_ADDRESS) {
					printf("Source is the local PAN coordinator.\r\n");
					result = TRUE;
				}
			}
		}
		return frame;
	}

	event void MLME_DISASSOCIATE.confirm(ieee154_status_t status, uint8_t DeviceAddrMode, uint16_t DevicePANID, ieee154_address_t DeviceAddress)
	{}

	event void MLME_ASSOCIATE.indication(uint64_t DeviceAddress,
											ieee154_CapabilityInformation_t CapabilityInformation,
											ieee154_security_t *security
											)
	{}

	event void MLME_SYNC_LOSS.indication(ieee154_status_t lossReason,
											uint16_t PANId,
											uint8_t LogicalChannel,
											uint8_t ChannelPage,
											ieee154_security_t *security
											)
	{
		startApp();
	}

	event void MLME_DISASSOCIATE.indication(uint64_t DeviceAddress,
											ieee154_disassociation_reason_t DisassociateReason,
											ieee154_security_t *security
											)
	{}

	event void MLME_COMM_STATUS.indication(uint16_t PANId, uint8_t SrcAddrMode,
											ieee154_address_t SrcAddr,
											uint8_t DstAddrMode,
											ieee154_address_t DstAddr,
											ieee154_status_t status,
											ieee154_security_t *security
											)
	{}

}
