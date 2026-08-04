#include <stdio.h>
#include <stdlib.h>
#include "cjson/cJSON.h"

int main(void)
{
	cJSON *root = cJSON_CreateObject();
	cJSON_AddStringToObject(root, "name", "BareMetal");
	cJSON_AddNumberToObject(root, "answer", 42);
	cJSON_AddBoolToObject(root, "exokernel", 1);

	cJSON *tags = cJSON_AddArrayToObject(root, "tags");
	cJSON_AddItemToArray(tags, cJSON_CreateString("x86-64"));
	cJSON_AddItemToArray(tags, cJSON_CreateString("unikernel"));

	char *rendered = cJSON_Print(root);
	printf("Encoded: %s\n", rendered);

	cJSON *parsed = cJSON_Parse(rendered);
	cJSON *name = cJSON_GetObjectItem(parsed, "name");
	cJSON *answer = cJSON_GetObjectItem(parsed, "answer");

	if (cJSON_IsString(name) && cJSON_IsNumber(answer)) {
		printf("Decoded name=%s answer=%d\n", name->valuestring, (int)answer->valuedouble);
		printf("cJSON test PASSED\n");
	} else {
		printf("cJSON test FAILED\n");
	}

	free(rendered);
	cJSON_Delete(parsed);
	cJSON_Delete(root);

	return 0;
}
