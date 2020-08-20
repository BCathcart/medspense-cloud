#include "database_api.h"
#include "serialcomm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Flow control
#define ACK 0x06
#define EOT 0x04

/* LUA Commands */
const char * RUN_BLINK = "dofile(\"blink.lua\")";
const char * RUN_DATABASE_TWILIO_COMM = "dofile(\"DynamoDB_Twilio_Comm_Prod.lua\")";
const char * SEND_TEXT_COMMAND = "send_help_text()";

/* Private Function Declarations */
void send_cmd_to_wifi_dongle(const char * cmd);


/*** Public Functions ***/

/* 
 * Delays (busy idles) the specified number of seconds.
 * @param seconds Number of seconds to delay.
 */
void delay(unsigned int seconds) {
    clock_t start_time = time(NULL);
    while (time(NULL) < start_time + seconds);
}

/* 
 * Fetches the user's medication data stored in DynamoDB.
 * @param user_id The user's Personal Health Number (PHN).
 * @param[out] medication_data The user's prescription data.
 * @param[out] num_prescriptions The number of prescriptions.
 * @return True if successfully retrieved user's medication data, false otherwise.
 * @warn The medication_data array may contain garbage data if the function returns false.
 */
bool DBComm_getMedicationData(const char * user_id, char (*medication_data)[][30], unsigned int * num_prescriptions) {
    if (medication_data == NULL || num_prescriptions == NULL) {
        return false;
    }

    // Construct get_user_data(user_id) command to send to Wi-Fi dongle
    int cmd_size = snprintf(NULL, 0, "%s%s%s", "get_user_data(\"", user_id, "\")");
    char * cmd_str = malloc(cmd_size + 1);
    snprintf(cmd_str, cmd_size + 1, "%s%s%s", "get_user_data(\"", user_id, "\")");

    printf("Cmd string: %s\n", cmd_str);
    send_cmd_to_wifi_dongle(cmd_str);
    free(cmd_str);

    // Flush until ACK received
    char c;
    while ((c = getCharWIFI()) != ACK) { }

    // Receive response from Wi-Fi dongle
    unsigned int table_index = 0, entry_index = 0;
    *num_prescriptions = 0;
    while ((c = getCharWIFI()) != EOT) {
        printf("%c", c);

        // Return false if user's data could not be fetched
        if (c == '\0') {
            return false;
        }

        // Populate table
        if (c == ',') {
        	(*medication_data)[table_index][entry_index] = '\0';
        	table_index++;
            entry_index = 0;
            if(table_index % 3 == 0){
        		(*num_prescriptions)++;
        	}
    	} 	else {
       		(*medication_data)[table_index][entry_index++] = c;
    	}
    }

    printf("\nDone reading input\n");

	return true;
}

/* 
 * Sends command to Wi-Fi dongle to run the blink script.
 */
void DBComm_runBlinkScript(void) {
    send_cmd_to_wifi_dongle(RUN_BLINK);
}

/* 
 * Sends command to Wi-Fi dongle to run the script for DynamoDB and Twilio communication.
 */
void DBComm_runDBTwilioCommScript(void) {
    send_cmd_to_wifi_dongle(RUN_DATABASE_TWILIO_COMM);
}

/* 
 * Sends a text to customer support notifying them that a user requires help.
 */
void DBComm_sendText(void) {
    send_cmd_to_wifi_dongle(SEND_TEXT_COMMAND);
}


/*** Private Functions ***/

/* 
 * Send command to Wi-Fi Dongle.
 * @param cmd Command string to send to wi-fi dongle.
 */
void send_cmd_to_wifi_dongle(const char * cmd) {
    if (cmd == NULL) {
        return;
    }

    for (int i = 0; i < strlen(cmd); i++) {
        putCharWIFI(cmd[i]);
    }
    putCharWIFI('\r');
    putCharWIFI('\n');
}
