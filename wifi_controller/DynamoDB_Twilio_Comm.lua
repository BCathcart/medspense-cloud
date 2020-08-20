DEBUG = false

-- Don't print if DEBUG is false
if DEBUG == false then
    function print() end
end

ACK = 6
EOT = 4

-- Wi-Fi Authentication
SSID= "network_name"
SSID_PASSWORD = "network_password"

-- Configure ESP as a station
wifi.setmode(wifi.STATION)

-- Connect to Wi-Fi
station_cfg={}
station_cfg.ssid=SSID
station_cfg.pwd=SSID_PASSWORD
station_cfg.save=true
wifi.sta.config(station_cfg)
wifi.sta.connect()

-- Register timer to check wifi connection
timer = tmr.create()
timer:register(3000, tmr.ALARM_SEMI, function()
        if wifi.sta.status() == 5 then
            print("Wi-Fi Connected!")
            -- Prints the IP given to ESP8266
            print(wifi.sta.getip())
        else
            print("Waiting for Wi-Fi connection")
            timer:start()
        end
    end)
timer:start()


-- AWS DynamoDB Communication --

CLOUDFRONT_DOMAIN = "CloudFront_domain"

-- Parses AWS response and forwards data to DE1
function handle_response(sck, data)
    print(sck, data)
    print(type(data))

    -- Find index of the response payload
    data_index = string.find(data, "%[")
    -- If no data is found, return NULL
    if data_index == nil then
        uart.write(0, ACK)
        uart.write(0, '\0')
        uart.write(0, EOT)
        return
    end

    data = string.sub(data, data_index)
    print(data)

    -- Decode JSON formatted data
    local decoder = sjson.decoder()
    decoder:write(data)
    medication_table = decoder:result()

    print(type(medication_table))

    -- Send ACK
    uart.write(0, ACK)

    -- Send comma-separated list of medication table fields
    for idx,sub_arr in pairs(medication_table) do
        print(idx, sub_arr)
        for idx2,val in pairs(sub_arr) do
            print(idx2, val)
            uart.write(0, val)
            uart.write(0, ',')
        end
    end

    -- Send EOT
    uart.write(0, EOT)
end

-- Fetches a user's data from AWS DynamoDB
function get_user_data(user_id)
    -- If there isn't a wifi connection return NULL
    if wifi.sta.status() ~= 5 then
        uart.write(0, ACK)
        uart.write(0, '\0')
        uart.write(0, EOT)
        return
    end

    request = "GET /?user_id="..user_id.." HTTP/1.1\r\n"..
    "Host: "..CLOUDFRONT_DOMAIN.."\r\n"..
    "Connection: keep-alive\r\n"..
    "Cache-Control: no-store\r\n"..
    "\r\n"

    print(request)

    socket = net.createConnection(net.TCP,0)
    socket:on("receive", handle_response)
    socket:connect(80, CLOUDFRONT_DOMAIN)

    socket:on("connection", function(sck)
        post_request = request
        sck:send(post_request)
    end)
end


-- Twilio Communication --

-- The following 2 pieces of information are related to your Twilio account the one you made in Exercise 1.9
-- change appropriately
TWILIO_ACCOUNT_SID = "account_id"
TWILIO_TOKEN =       "account_token"

-- Unfortunately, the Wi-FI dongle can only make unsecured HTTP requests, but Twilio requires 
-- secured HTTPS requests, so we will use a relay website to convert HTTP requests into HTTPS requests
-- visit http://iot-https-relay.appspot.com/ to learn more about this service
-- Please be sure to understand the security issues of using this relay app and use at your own risk.

-- this is the web address of the relay web site that our dongle sends the initial HTTP request to
HOST = "iot-https-relay.appspot.com" 

-- The following variable defines the TWILIO web site that we will connect to
-- use the first one if you want to send a text to a cell phone
-- use the second (commented out) one if you want to make a call to a cell phone - that's the only change
URI = "/twilio/Messages.json"
--URI = "/twilio/Calls.json"

function build_post_request(host, uri, data_table)
    data = ""

    for param,value in pairs(data_table) do
        data = data .. param.."="..value.."&"
    end

    request = "POST "..uri.." HTTP/1.1\r\n"..
    "Host: "..host.."\r\n"..
    "Connection: close\r\n"..
    "Content-Type: application/x-www-form-urlencoded\r\n"..
    "Content-Length: "..string.len(data).."\r\n"..
    "\r\n"..
    data
    print(request)
    return request
end

-- This function registers a function to echo back any response from the server, to our DE1/NIOS system 
-- or hyper-terminal (depending on what the dongle is connected to)
function display(sck,response)
    print(response)
end

-- When using send_sms: the "from" number HAS to be your twilio number.
-- If you have a free twilio account the "to" number HAS to be your twilio verified number.
function send_sms(from,to,body)
    data = {
        sid = TWILIO_ACCOUNT_SID,
        token = TWILIO_TOKEN,
        Body = string.gsub(body," ","+"),
        From = from,
        To = to
    }

    socket = net.createConnection(net.TCP,0)
    socket:on("receive",display)
    socket:connect(80,HOST)

    socket:on("connection",function(sck)
        post_request = build_post_request(HOST,URI,data)
        sck:send(post_request)
    end)
end

function send_help_text()
    ip = wifi.sta.getip()

    if(ip==nil) then
        print("Connecting...")
    else
        print("Connected to AP!")
        print(ip)
        -- send a text message from, to, text
        send_sms("(604) 260-0085","(778) 713-2535","MEDSPENSE - User Requires Assistance")
    end
end

    