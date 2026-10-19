#include <unistd.h>
#include "network.h"
#include "../sketchybar.h"

// "512B", "40K", "1.2M": one decimal only below 10 so the label stays ~4 chars
static void compact(char* out, size_t len, double value, enum unit unit) {
  static const char suffix[] = { 'B', 'K', 'M' };
  snprintf(out, len, (unit != UNIT_BPS && value < 10) ? "%.1f%c" : "%.0f%c", value, suffix[unit]);
}

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 4 || (sscanf(argv[3], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<interface>\" \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[2]);
  sketchybar(event_message);

  struct network network;
  network_init(&network, argv[1]);
  char trigger_message[512];
  char up[16], down[16];
  for (;;) {
    // Acquire new info
    network_update(&network);

    // Prepare the event message
    compact(up, sizeof(up), network.up, network.up_unit);
    compact(down, sizeof(down), network.down, network.down_unit);
    snprintf(trigger_message,
             512,
             "--trigger '%s' upload='%s' download='%s'",
             argv[2],
             up,
             down);

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
