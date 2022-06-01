#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

#define MAX_MISSING_TIME 60000
#define SENSING_TIME 10000

// Message struct
typedef nx_struct sb_msg {
  	nx_uint8_t msg_type;
  	nx_uint16_t msg_id;

  	nx_uint8_t data[20];
  	nx_uint16_t X;
  	nx_uint16_t Y;
} sb_msg_t;

typedef struct sensorStatus {
  uint8_t status[10];
  uint16_t X;
  uint16_t Y;
} sensor_status;


// Constants
enum {
  AM_RADIO_TYPE = 6,
};


// Pre-loaded random keys
#define FOREACH_KEY(KEY) \
        KEY(qD2UjB93kvyULDJMnGNq) \
        KEY(nuyb8byn98uiyi8u9uBF) \
        
#define GENERATE_ENUM(ENUM) ENUM,
#define GENERATE_STRING(STRING) #STRING,
enum KEY_ENUM {
    FOREACH_KEY(GENERATE_ENUM)
};
static const char *RANDOM_KEY[] = {
    FOREACH_KEY(GENERATE_STRING)
};

#endif
