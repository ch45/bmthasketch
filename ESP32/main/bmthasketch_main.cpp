/* ESP32_Bmth_A_Sketch_USB_main.c */

#include <string>
#include <deque>
#include "driver/gpio.h"
#include "driver/uart.h"
#include "esp_log.h"
#include "esp_spi_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"

void chip_info();

static const int SEND_FREQ_MS = 250;
static const int READ_WAIT_MS = 250;
static const int RX_BUF_SIZE = 1024;

#define TXD_PIN (GPIO_NUM_1) /* TXD0 GPIO1 */
#define RXD_PIN (GPIO_NUM_3) /* RXD0 GPIO3 */

std::deque<std::string> echoBuffer;

void init(void)
{
    const uart_config_t uart_config = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .rx_flow_ctrl_thresh = 122,
        .source_clk = UART_SCLK_APB,
    };
    // We won't use a buffer for sending data.
    uart_driver_install(UART_NUM_0, RX_BUF_SIZE * 2, 0, 0, NULL, 0);
    uart_param_config(UART_NUM_0, &uart_config);
    uart_set_pin(UART_NUM_0, TXD_PIN, RXD_PIN, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
}


int sendData(const char* logName, std::deque<std::string> &deck)
{
    int totalBytes = 0;
    int packetsTried = 0;

    while (!deck.empty()) {
        packetsTried++;
        std::string str = deck.front();
        const char* data = str.c_str();
        const int len = str.size();
        const int txBytes = uart_write_bytes(UART_NUM_0, data, len);
        if (txBytes > 0) {
            deck.pop_front();
            totalBytes += txBytes;
        } else {
            break; // TODO keep buffering until we can send!
        }
    }

    if (packetsTried > 0) {
        ESP_LOGI(logName, "Wrote %d packets %d total bytes", packetsTried, totalBytes);   
    }
    return totalBytes;
}

int receiveData(uint8_t* data, int len, std::deque<std::string> &deck)
{
    int validPackets = 0;
    std::string prefixIn("TX->ESP32");
    std::string prefixOut("RX<-ESP32");

    std::string str_data((char *)data, len);

    int end = str_data.find('\n');
    int start = 0;
    while (end != std::string::npos) {
        std::string str = str_data.substr(start, end - start);
        if (str.substr(0, prefixIn.size()) == prefixIn) {
            validPackets++;
            str.replace(0, prefixOut.size(), prefixOut);
            str.append("\n");
            deck.push_back(str);
            start = end + 1;
            end = str_data.find('\n', start);
        }
    }
    return validPackets;
}

static void tx_task(void *arg)
{
    static const char *TX_TASK_TAG = "TX_TASK";
    esp_log_level_set(TX_TASK_TAG, ESP_LOG_INFO);
    while (1) {
        sendData(TX_TASK_TAG, echoBuffer);
        vTaskDelay(SEND_FREQ_MS / portTICK_PERIOD_MS);
    }
}

static void rx_task(void *arg)
{
    static const char *RX_TASK_TAG = "RX_TASK";
    esp_log_level_set(RX_TASK_TAG, ESP_LOG_INFO);
    uint8_t* data = (uint8_t*) malloc(RX_BUF_SIZE+1);
    while (1) {
        const int rxBytes = uart_read_bytes(UART_NUM_0, data, RX_BUF_SIZE, READ_WAIT_MS / portTICK_RATE_MS);
        if (rxBytes > 0) {
            receiveData(data, rxBytes, echoBuffer);
            ESP_LOGI(RX_TASK_TAG, "Read %d bytes: '%s'", rxBytes, data);
            // ESP_LOG_BUFFER_HEXDUMP(RX_TASK_TAG, data, rxBytes, ESP_LOG_INFO);
        }
    }
    free(data);
}


extern "C" void app_main()
{
    init();
    chip_info();

    xTaskCreate(rx_task, "uart_rx_task", 1024*2, NULL, configMAX_PRIORITIES, NULL);
    xTaskCreate(tx_task, "uart_tx_task", 1024*8, NULL, configMAX_PRIORITIES-1, NULL);
}

void chip_info()
 {
    /* Print chip information */
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    printf("This is ESP32 chip with %d CPU cores, WiFi%s%s, ",
           chip_info.cores,
           (chip_info.features & CHIP_FEATURE_BT) ? "/BT" : "",
           (chip_info.features & CHIP_FEATURE_BLE) ? "/BLE" : "");

    printf("silicon revision %d, ", chip_info.revision);

    printf("%dMB %s flash\n", spi_flash_get_chip_size() / (1024 * 1024),
           (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external");
}
