#ifndef DATABASE_API_H
#define DATABASE_API_H

#include <stdbool.h>

/* Delays (busy idles) the specified number of seconds */
void delay(unsigned int seconds);

/* Fetches the user's medication data stored in DynamoDB. */
bool DBComm_getMedicationData(const char * user_id, char (*medication_data)[][30], unsigned int * num_prescriptions);
 
/* Sends command to Wi-Fi dongle to run the blink script. */
void DBComm_runBlinkScript(void);

/* Sends command to Wi-Fi dongle to run the script for DynamoDB and Twilio communication.*/
void DBComm_runDBTwilioCommScript(void);

/* Sends a text to customer support notifying them that a user requires help. */
void DBComm_sendText(void);

#endif  // DATABASE_API_H