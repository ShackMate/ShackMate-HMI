/*
Declaring enums
*/

const Radio_Type = {
  Generic:      "Generic",      // Generic radio of any make/model
  Generic_Icom: "Generic_Icom", // Generic Icom radio
  IC_7300:      "IC-7300",      // Icom IC-7300
  IC_9700:      "IC-9700"       // Icom IC-9700
};

const PoweringState = {
  On:         "on",          // 
  Off:        "off",         // 
  TurningOn:  "turning_on",  // 
  TurningOff: "turning_off", // 
  Unknown:    "unknown"      // 
};

const VFOSide = {
  A: 0, // 
  B: 1  // 
};

const OperateMode = {
  VFO: "VFO", // 
  MEM: "MEM"  // 
}


var logCount = 0;
console_log = function (logMessage) {
    var logger = console_info(logMessage);
    logCount++;
    if (logCount > 500) {
      console.clear();
      logCount = 0;
    }
}


class HardwareControls {
  #eventTarget = new EventTarget();

  constructor() {

    document.addEventListener('keyup', (event) => {
      //console_log(`Key released: ${event.key}`);
    });

    document.addEventListener('keydown', (event) => {
      //console_log(`Key pressed: ${event.key}`);

      if (event.key === 'ArrowUp') {
        var e = new CustomEvent("harware_event", {detail: event.key});
        this.dispatchEvent(e);

        var e = new CustomEvent(event.key, {detail: event.key});
        this.dispatchEvent(e);
      }
      else if (event.key === 'ArrowDown') {
        var e = new CustomEvent(event.key, {detail: event.key});
        this.dispatchEvent(e);
      }

    });
  }

  addEventListener(eventName, callback) {

    this.#eventTarget.addEventListener(eventName, callback);
  }

  removeEventListener(eventName, callback) {

    this.#eventTarget.removeEventListener(eventName, callback);
  }

  dispatchEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail: detail });
    //document.dispatchEvent(event);
    this.#eventTarget.dispatchEvent(event);
  }


}


class SMPoll {
  #command = "";
  #activeInterval = 60000;
  #inactiveInterval = 60000;
  #pollRX = false;
  #pollTX = false;
  #pollInactive = false;
  #pollOn = false
  #pollOff = false
  #lastPolled = new Date();


  constructor(command, activeInterval, inactiveInterval, pollRX, pollTX, pollInactive, pollOn, pollOff ) {
    this.#command = command;
    this.#activeInterval = activeInterval;
    this.#inactiveInterval = inactiveInterval;
    this.#pollRX = (pollRX) ? pollRX : this.#pollRX;
    this.#pollTX = (pollTX) ? pollTX : this.#pollTX;
    this.#pollInactive = (pollInactive) ? pollInactive : this.#pollInactive;
    this.#pollOn = (pollOn) ? pollOn : this.#pollOn;
    this.#pollOff = (pollOff) ? pollOff : this.#pollOff;
  }

  get command() {return this.#command;}
  set command(x) {this.#command= x;}
  get interval() {return this.#activeInterval;}
  set interval(x) {this.#activeInterval = x;}
  get activeInterval() {return this.#activeInterval;}
  set activeInterval(x) {this.#activeInterval = x;}
  get inactiveInterval() {return this.#inactiveInterval;}
  set inactiveInterval(x) {this.#inactiveInterval = x;}
  get pollRX() {return this.#pollRX;}
  set pollRX(x) {this.#pollRX= x;}
  get pollTX() {return this.#pollTX;}
  set pollTX(x) {this.#pollTX= x;}
  get pollInactive() {return this.#pollInactive;}
  set pollInactive(x) {this.#pollInactive= x;}
  get pollOn() {return this.#pollOn;}
  set pollOn(x) {this.#pollOn= x;}
  get pollOff() {return this.#pollOff;}
  set pollOff(x) {this.#pollOff= x;}
  get lastPolled() {return this.#lastPolled.valueOf();}
  set lastPolled(x) {this.#lastPolled = x;}
}


class SMPollRadioIcom {
  #arrObjPoll = [];
  #boolPoll = false;
  #pollingInterval = 50;
  #lastPolled = new Date();
  #eventTarget = new EventTarget();
  #lastIndex = -1;
  #objSMRadioIcom;

  constructor(objSMRadioIcom) {
    this.#objSMRadioIcom = objSMRadioIcom;

    /*SMPoll(command, activeInterval, inactiveInterval, pollRX, pollTX, pollInactive, pollOn, pollOff)*/
    this.add(new SMPoll("0F", 1000, 2000, true, true, true, true, false));   // TX/RX
    this.add(new SMPoll("14 01", 1000, 2000, true, true, true, true, false)); // AF Level
    this.add(new SMPoll("15 01", 300, 500, true, false, true, true, false));  // Squelch Status
    this.add(new SMPoll("15 02", 300, 500, true, false, true, true, false));  // S Meter
    this.add(new SMPoll("15 11", 500, 1000, false, true, true, true, false)); // PO Meter
    this.add(new SMPoll("15 12", 500, 1000, false, true, true, true, false)); // SWR Meter
    this.add(new SMPoll("15 13", 500, 1000, false, true, true, true, false)); // ALC Meter
    this.add(new SMPoll("15 14", 500, 1000, false, true, true, true, false)); // COMP Meter
    this.add(new SMPoll("15 15", 2000, 5000, true, true, true, true, false)); // Voltage Meter
    this.add(new SMPoll("15 16", 500, 1000, true, true, true, true, false));  // Current Meter
    this.add(new SMPoll("16 42", 500, 1000, true, true, true, true, false));  // Tone Enabled?
    this.add(new SMPoll("16 43", 500, 1000, true, true, true, true, false));  // TSQL Enabled?
    this.add(new SMPoll("16 5D", 500, 1000, true, true, true, true, false));  // Tone/DTCS Enabled?
    this.add(new SMPoll("19 00", 3000, 9000, true, true, true, false, true)); // Transceiver ID
    this.add(new SMPoll("1C 00", 300, 500, true, true, true, true, false));   // TX/RX
    this.add(new SMPoll("25 01", 500, 1000, true, true, true, true, false));  // Unselected VFO Freq

    setInterval( () => {
      let boolFirstRun = false;
      if (this.#boolPoll) {
        const pollRuntime = (new Date()).valueOf();

        for (let i = 0; i < this.#arrObjPoll.length; i++) {
          const poll = this.#arrObjPoll[i];
          if (!boolFirstRun) {
            let vfoIndex = this.#objSMRadioIcom._activeVFOIndex;
            let vfo = this.#objSMRadioIcom._arrVFO[vfoIndex];

            const radioIsActive = this.#objSMRadioIcom.active;
            const txIsActive = vfo.tx;
            const powerIsOn = this.#objSMRadioIcom._powerOn;

            let currentInterval = 0;
            //(radioIsActive) ? currentInterval = poll.activeInterval : currentInterval = poll.inactiveInterval;
            currentInterval = (radioIsActive) ? poll.activeInterval : poll.inactiveInterval;

            // Is it time to run the poll?
            if (poll.lastPolled + currentInterval < pollRuntime) {

              // Should we poll during RX and/or TX?
              if (poll.pollRX != txIsActive || poll.pollTX == txIsActive) {

                // Should we poll when active/inactive?
                if (radioIsActive || poll.pollInactive) {

                  // Should we poll when off?
                  if ((powerIsOn && poll.pollOn) || (!powerIsOn && poll.pollOff)) {
                    this.execute(poll);
                    boolFirstRun = true;
                  }

                }

              }

            }
          }
        }
      }
    }, this.#pollingInterval);

  }

  get length() {return this.#arrObjPoll.length;}

  add(objPoll) {
    if (this.#arrObjPoll.length == 0) {
      this.#arrObjPoll = [objPoll];
    } else {
      this.#arrObjPoll.push(objPoll)
    }
  }

  sleep(ms) {

    return new Promise(resolve => setTimeout(resolve, ms));
  }

  addEventListener(eventName, callback) {

    this.#eventTarget.addEventListener(eventName, callback);
  }

  removeEventListener(eventName, callback) {

    this.#eventTarget.removeEventListener(eventName, callback);
  }

  dispatchEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail: detail });
    //document.dispatchEvent(event);
    this.#eventTarget.dispatchEvent(event);
  }

  start() {
    // Start polling...
    this.#boolPoll = true;
  }

  stop() {
    // Stop polling...
    this.#boolPoll = false;
  }

  execute(poll) {
    const dtNow = new Date();
    this.#lastPolled = dtNow;
    poll.lastPolled = dtNow;
    console_log(`executing poll: ${poll.command}`);
    this.#objSMRadioIcom.sendCommand(poll.command, true);
    // add event to notify poll was executed...
  }
}

class SMDeviceRouter { /* Base Object - Shack Mate Device */
  #baudrate = 0 //115200;
  _socket = undefined;
  _arrSend = [];
  _arrPoll = [];
  _lastSend = new Date();
  _minimumDuplicateInterval = 100;
  _minimumSendInterval = 50;
  _lastResponseDt = new Date(0);
  url = "";
  eventTarget = new EventTarget();
  _displayAddress = "";
  _lastMessage = "";
  _badCount = 0;
  _maxBadCount = 5;
  _lastSocketReadyState = WebSocket.CLOSED;
  _sendBinary = false;

  constructor(url, displayAddress = 'EE') {
    console_log("shackmate.js::SMDeviceRouter => NEW ROUTER DEVICE CREATED!");
    this.url = url;
    this._displayAddress = displayAddress;

    this.connectWebSocket();

    setInterval(() => {
      const currentState = this._socket.readyState;
      const eventName = "WebSocket";
      let eventDetail = "";

      if (currentState != this._lastSocketReadyState) {
          switch (currentState) {
          case WebSocket.CONNECTING:
            eventDetail = "CONNECTING";
            break;

          case WebSocket.OPEN:
            eventDetail = "OPEN";
            break;

          case WebSocket.CLOSING:
            eventDetail = "CLOSING";
            break;

          case WebSocket.CLOSED:
            eventDetail = "CLOSED";
            break;
        }
        
        this._lastSocketReadyState = currentState;
        this.dispatchEvent(eventName, eventDetail);
      }
    }, 100);
  }

  get baudrate() {return this.#baudrate;}
  get minimumSendInterval() {return this._minimumSendInterval;}
  set minimumSendInterval(x) {this._minimumSendInterval = x;}
  get displayAddress() {return this._displayAddress;}
  set displayAddress(x) {this._displayAddress = x;}

  connectWebSocket() {
    this._socket = new WebSocket(this.url);

    this._socket.onopen = () => {
      console_log("shackmate.js::SMDeviceRouter -> WebSocket connection opened to " + this.url);
      this.dispatchEvent("ready", "device is ready");
    };

    this._socket.onmessage = (event) => {
      const previousResponse = this._lastResponseDt;
      this._lastResponseDt = new Date();
      const message = event.data.toUpperCase().trim();
      const bytes = message.split(" ");
      if (bytes[0] == "FE" && bytes[1] == "FE") {
        if (bytes[2] == this._displayAddress || bytes[2] == "00") {
          if (message == this._lastMessage 
            && previousResponse.valueOf() + this._minimumDuplicateInterval > this._lastResponseDt.valueOf()) {
            //console_log("shackmate.js::SMDeviceRouter -> Received Duplicate: " + message);
          }
          else {
            console_log("shackmate.js::SMDeviceRouter -> Received: " + message);

            const decodedResponse = this.decodeResponse(message);

            if (decodedResponse.validMessage) {
              if (decodedResponse.bytesFrom[0] != this._displayAddress) {
                this.dispatchEvent(decodedResponse.bytesFrom[0], decodedResponse);
              }
            }
          }
          this._lastMessage = message;
        }
        else {
          console_log("shackmate.js::SMDeviceRouter -> Ignoring: " + message);
        }
      }
      else {
        this._badCount++;
        console_error("Encountered bad message...", this._badCount);

        if (this._badCount > this._maxBadCount) {
          console_error("Encountered maximum bad messages... ", this._maxBadCount);
          this._socket.close();
          this._badCount = 0;
        }
      }
      };

    this._socket.onerror = function(error) {
      console_error("shackmate.js::SMDeviceRouter -> WebSocket error:", error);
    };

    this._socket.onclose = () => {
      let strResponse = "shackmate.js::SMDeviceRouter -> WebSocket connection closed. ";
      strResponse += "Attempting to reconnect in 3 seconds...";
      this.dispatchEvent("not ready", "device is not ready");
      console_log(strResponse);
      setTimeout(() => {
        this.connectWebSocket();
      }, 2000);
    };
  }

  send(data, boolPoll = false) {
    // Only send if the socket is in the OPEN state.
    if (this._socket && this._socket.readyState === WebSocket.OPEN) {

      const rightNow = new Date();
      if (this._lastSend.valueOf() + this._minimumSendInterval < rightNow.valueOf()) {
        this._lastSend = new Date();
        console_log(`SMDeviceRouter::send() -> Sending: ${data}`);
        if (this._sendBinary) {
          const hexData = data.replaceAll(" ", "");
          const binData = Uint8Array.from(hexData.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
          this._socket.send(binData);
        }
        else {
          this._socket.send(data);
        }
      } else {
        if (!boolPoll) {
          // Queueing Priority...
          if (this._arrSend.length == 0) {
            this._arrSend = [data];
            setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
          } else {
            let boolFound = false;
            for (let i = 0; i < this._arrSend.length; i++) {
              if (this._arrSend[i] == data) {
                boolFound = true;
                break;
              }
            }
            if (!boolFound) {
              this._arrSend.push(data)
            }
          }
          console_log(`SMDeviceRouter::send() -> Queueing outbound message [${this._arrSend.length} priority]: ${data}`);
        }
        else {
          // Queueing Poll...
          if (this._arrPoll.length == 0) {
            this._arrPoll = [data];
            setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
          } else {
            let boolFound = false;
            for (let i = 0; i < this._arrPoll.length; i++) {
              if (this._arrPoll[i] == data) {
                boolFound = true;
                break;
              }
            }
            if (!boolFound) {
              this._arrPoll.push(data)
            }
          }
          console_log(`SMDeviceRouter::send() -> Queueing outbound message [${this._arrPoll.length} poll]: ${data}`);
        }

      }
    } else {
      console_error("SMDeviceRouter::send() -> WebSocket is not open. Current state:"
                   , this.socket ? this.socket.readyState : "No socket");
    }
  }

  sendFromQueue() {
    // Only send if the socket is in the OPEN state.
    if (this._socket && this._socket.readyState === WebSocket.OPEN) {

      let rightNow = new Date();
      if (this._lastSend.valueOf() + this._minimumSendInterval < rightNow.valueOf()) {
        if (this._arrSend.length > 0) {
          let data = this._arrSend.shift();
          this._lastSend = new Date();
          console_log(`SMDeviceRouter::sendFromQueue() -> Sending [${this._arrSend.length} priority]: ${data}`);
          if (this._sendBinary) {
            const hexData = data.replaceAll(" ", "");
            const binData = Uint8Array.from(hexData.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
            //const binData = Uint8Array.fromHex(data.replaceAll(" ",""));
            this._socket.send(binData);
          }
          else {
            this._socket.send(data);
          }
          if (this._arrSend.length > 0) {
            setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
          }
        }
        else if (this._arrPoll.length > 0) {
          let data = this._arrPoll.shift();
          this._lastSend = new Date();
          console_log(`SMDeviceRouter::sendFromQueue() -> Sending [${this._arrPoll.length} poll]: ${data}`);
          if (this._sendBinary) {
            const hexData = data.replaceAll(" ", "");
            const binData = Uint8Array.from(hexData.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
            //const binData = Uint8Array.fromHex(data.replaceAll(" ",""));
            this._socket.send(binData);
          }
          else {
            this._socket.send(data);
          }
          if (this._arrPoll.length > 0) {
            setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
          }
        }
        else {
          console_log("SMDeviceRouter::sendFromQueue() -> No messages are pending");
        }
      } else {
        if (this._arrSend.length > 0) {
          let data = this._arrSend[0];
          console_log(`SMDeviceRouter::sendFromQueue() -> Waiting to send queued outbound message [${this._arrSend.length} priority]: ${data}`);
          setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
        } 
        else if (this._arrPoll.length > 0) {
          let data = this._arrPoll[0];
          console_log(`SMDeviceRouter::sendFromQueue() -> Waiting to send queued outbound message [${this._arrSend.length} poll]: ${data}`);
          setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
        } 
        else {
          console_log("SMDeviceRouter::sendFromQueue() -> No messages are pending");
        }
      }
    } else {
      console_error("SMDeviceRouter::sendFromQueue() -> WebSocket is not open. Current state:"
                   , this.socket ? this.socket.readyState : "No socket");
      setTimeout(() => {this.sendFromQueue()}, this._minimumSendInterval);
    }
  }

  addEventListener(eventName, callback) {

    this.eventTarget.addEventListener(eventName, callback);
  }

  removeEventListener(eventName, callback) {

    this.eventTarget.removeEventListener(eventName, callback);
  }

  dispatchEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail: detail });
    //document.dispatchEvent(event);
    this.eventTarget.dispatchEvent(event);
  }

  decodeResponse(message) {
    let bytesPreamble = [];
    let bytesTo = [];
    let bytesFrom = [];
    let bytesOK = [];
    let bytesCommandNumber = [];
    let bytesSubCommandNumber = [];
    let bytesData = [];
    let bytesEndOfMessage = [];

    message = message.toUpperCase();
    message = message.trim();
    const bytes = message.split(" ");
    if (bytes.length >= 6 && bytes[0] == "FE" && bytes[1] == "FE") {
      //Valid to decode...
      bytesPreamble.push(bytes[0]);
      bytesPreamble.push(bytes[1]);
      
      bytesTo.push(bytes[2]);
      bytesFrom.push(bytes[3]);

      if (bytes.length === 6) {
        //  OK / NG Response
        bytesOK.push(bytes[4]);

      } else if (bytes.length > 6) {
        // Command Response
        bytesCommandNumber.push(bytes[4]);

        let intDataStart = 5;
        if (this.expectSubcommand(bytesCommandNumber[0])) {
          bytesSubCommandNumber.push(bytes[5]);
          intDataStart = 6;
        }

        for (let i = intDataStart; i < bytes.length - 1; i++) {
          bytesData.push(bytes[i]);
        }

      }

      bytesEndOfMessage.push(bytes[bytes.length - 1]);

      /*
      console_log("bytesPreamble: ", bytesPreamble);
      console_log("bytesTo: ", bytesTo);
      console_log("bytesFrom: ", bytesFrom);
      console_log("bytesCommandNumber: ", bytesCommandNumber);
      console_log("bytesSubCommandNumber: ", bytesSubCommandNumber);
      console_log("bytesData: ", bytesData);
      console_log("bytesOK: ", bytesOK);
      console_log("bytesEndOfMessage: ", bytesEndOfMessage);
      */

      return {
        validMessage: true,
        bytesPreamble: bytesPreamble,
        bytesTo: bytesTo,
        bytesFrom: bytesFrom,
        bytesCommandNumber: bytesCommandNumber,
        bytesSubCommandNumber: bytesSubCommandNumber,
        bytesData: bytesData,
        bytesOK: bytesOK,
        bytesEndOfMessage: bytesEndOfMessage
      };
    }
    else {
      // If the message doesn't match our expected format, return it as is.
      this._badCount++;
      console_error("Encountered bad message...", this._badCount);

      if (this._badCount > this._maxBadCount) {
        console_error("Encountered maximum bad messages... ", this._maxBadCount);
        this._socket.close();
        this._badCount = 0;
      }

      return {
        validMessage: false,
        unhandledResponse: message
      };/* Function to decode the received command. */
    }
  }

  expectSubcommand(command) {
    let boolReturn = false;

    switch(command) {
      case "07":
      case "0E":
      case "13":
      case "14":
      case "15":
      case "16":
      case "18":
      case "19":
      case "1A":
      case "1B":
      case "1C":
      case "1E":
      case "21":
      case "27":
      case "28":
        boolReturn = true;
    }

    return boolReturn;
  }
}

class VFO {
  toneList = ["--", "67.0" ,"69.3" ,"71.9" ,"74.4" ,"77.0" ,"79.7" ,"82.5" ,"85.4" ,"88.5"
             ,"91.5" ,"94.8" ,"97.4" ,"100.0" ,"103.5" ,"107.2" ,"110.9" ,"114.8" ,"118.8" ,"123.0"
             ,"127.3" ,"131.8" ,"136.5" ,"141.3" ,"146.2" ,"151.4" ,"156.7" ,"159.8" ,"162.2" ,"165.5"
             ,"167.9" ,"171.3" ,"173.8" ,"177.3" ,"179.9" ,"183.5" ,"186.2" ,"189.9" ,"192.8" ,"196.6"
             ,"199.5", "203.5" ,"206.5" ,"210.7" ,"218.1" ,"225.7" ,"229.1" ,"233.6" ,"241.8" ,"250.3"
             ,"254.1"];
  dtcsList = ["--", "023", "025", "026", "031", "032", "036", "043", "047", "051"
             ,"053", "054" ,"065" ,"071" ,"072" ,"073" ,"074" ,"114" ,"115" ,"116"
             ,"122" ,"125" ,"131" ,"132" ,"134" ,"143" ,"145" ,"152" ,"155" ,"156"
             ,"162" ,"165" ,"172" ,"174" ,"205" ,"212" ,"223" ,"225" ,"226" ,"243"
             ,"244" ,"245" ,"246" ,"251" ,"252" ,"255" ,"261" ,"263" ,"265" ,"266"
             ,"271" ,"274" ,"306" ,"311" ,"315" ,"325" ,"331" ,"332" ,"343" ,"346"
             ,"351" ,"356" ,"364" ,"365" ,"371" ,"411" ,"412" ,"413" ,"423" ,"431"
             ,"432" ,"445" ,"446" ,"452" ,"454" ,"455" ,"462" ,"464" ,"465" ,"466"
             ,"503" ,"506" ,"516" ,"523" ,"526" ,"532" ,"546" ,"565" ,"606" ,"612"
             ,"624" ,"627" ,"631" ,"632" ,"654" ,"662" ,"664" ,"703" ,"712" ,"723"
             ,"731" ,"732" ,"734" ,"743" ,"754"];
  _frequency = "";
  _filter = "";
  _mode = "";
  _split = false;
  tx = false;
  _data = false;
  _initialized = false;
  _smeter = 0;
  _pometer = 0;
  _swrmeter = 0;
  _squelch = 0;
  txPolarityNormal = true;
  rxPolarityNormal = true;
  #toneListIndex = 0;
  #tsqlListIndex = 0;
  #dtcsListIndex = 0;
  txToneEnabled = false;
  txDtcsEnabled = false;
  rxToneEnabled = false;
  rxDtcsEnabled = false;
  simplex = true;
  duplexUp = false;
  duplexDown = false;

  constructor() {}

  get tone() {return this.toneList[this.#toneListIndex];}
  set tone(x) {
    let hexTone = "000000" + x.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);

    for (let i = 0; i < this.toneList.length; i++) {
      let toneListHex = "000000" + this.toneList[i].replaceAll(".", "").replaceAll("-","");
      toneListHex = toneListHex.substring(toneListHex.length - 6, toneListHex.length);

      // Try matching on decimal value (as string)...
      if (x == this.toneList[i]) {
        this.#toneListIndex = i;
        break;
      }
      // Try matching on he
      else if (hexTone == toneListHex) {
        this.#toneListIndex = i;
        break;
      }
    }
  }
  get tsql() {return this.toneList[this.#tsqlListIndex];}
  set tsql(x) {
    let hexTone = "000000" + x.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);

    for (let i = 0; i < this.toneList.length; i++) {
      let toneListHex = "000000" + this.toneList[i].replaceAll(".", "").replaceAll("-","");
      toneListHex = toneListHex.substring(toneListHex.length - 6, toneListHex.length);

      // Try matching on decimal value (as string)...
      if (x == this.toneList[i]) {
        this.#tsqlListIndex = i;
        break;
      }
      // Try matching on he
      else if (hexTone == toneListHex) {
        this.#tsqlListIndex = i;
        break;
      }
    }
  }
  get dtcs() {return this.dtcsList[this.#dtcsListIndex];}
  set dtcs(x) {
    let hexDtcs = "000000" + x.replaceAll(".", "").replaceAll("-","");
    hexDtcs = hexDtcs.substring(hexDtcs.length - 6, hexDtcs.length);

    for (let i = 0; i < this.dtcsList.length; i++) {
      let dtcsListHex = "000000" + this.dtcsList[i].replaceAll(".", "").replaceAll("-","");
      dtcsListHex = dtcsListHex.substring(dtcsListHex.length - 6, dtcsListHex.length);

      // Try matching on decimal value (as string)...
      if (x == this.dtcsList[i]) {
        this.#dtcsListIndex = i;
        break;
      }
      // Try matching on he
      else if (hexDtcs == dtcsListHex) {
        this.#dtcsListIndex = i;
        break;
      }
    }
  }
  get toneHex() {
    let hexTone = this.toneList[this.#toneListIndex];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get tsqlHex() {
    let hexTone = this.toneList[this.#tsqlListIndex];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get dtcsHex() {
    let hexDtcs = this.dtcsList[this.#dtcsListIndex];
    hexDtcs = "000000" + hexDtcs.replaceAll(".", "").replaceAll("-","");
    hexDtcs = hexDtcs.substring(hexDtcs.length - 6, hexDtcs.length);
    return this.addPolarityPrefix(hexDtcs);
  }
  get nextTone() {return this.toneList[(this.#toneListIndex + 1) % this.toneList.length]}
  get nextTsql() {return this.toneList[(this.#tsqlListIndex + 1) % this.toneList.length]}
  get nextDtcs() {return this.dtcsList[(this.#dtcsListIndex + 1) % this.dtcsList.length]}
  get previousTone() {return this.toneList[(this.#toneListIndex + this.toneList.length - 1) % this.toneList.length]}
  get previousTsql() {return this.toneList[(this.#tsqlListIndex + this.toneList.length - 1) % this.toneList.length]}
  get previousDtcs() {return this.dtcsList[(this.#dtcsListIndex + this.dtcsList.length - 1) % this.dtcsList.length]}
  get nextToneHex() {
    let hexTone = this.toneList[(this.#toneListIndex + 1) % this.toneList.length];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get nextTsqlHex() {
    let hexTone = this.toneList[(this.#tsqlListIndex + 1) % this.toneList.length];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get nextDtcsHex() {
    let hexDtcs = this.dtcsList[(this.#dtcsListIndex + 1) % this.dtcsList.length];
    hexDtcs = "000000" + hexDtcs.replaceAll(".", "").replaceAll("-","");
    hexDtcs = hexDtcs.substring(hexDtcs.length - 6, hexDtcs.length);
    return this.addPolarityPrefix(hexDtcs);
  }
  get previousToneHex() {
    let hexTone = this.toneList[(this.#toneListIndex + this.toneList.length - 1) % this.toneList.length];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get previousTsqlHex() {
    let hexTone = this.toneList[(this.#tsqlListIndex + this.toneList.length - 1) % this.toneList.length];
    hexTone = "000000" + hexTone.replaceAll(".", "").replaceAll("-","");
    hexTone = hexTone.substring(hexTone.length - 6, hexTone.length);
    return hexTone;
  }
  get previousDtcsHex() {
    let hexDtcs = this.dtcsList[(this.#dtcsListIndex + this.dtcsList.length - 1) % this.dtcsList.length];
    hexDtcs = "000000" + hexDtcs.replaceAll(".", "").replaceAll("-","");
    hexDtcs = hexDtcs.substring(hexDtcs.length - 6, hexDtcs.length);
    return this.addPolarityPrefix(hexDtcs);
  }

  addPolarityPrefix(dtcsHex) {
    let dtcsPrefix = "00";
    if (this.txPolarityNormal && this.rxPolarityNormal) {
      dtcsPrefix = "00";
    } else if (this.txPolarityNormal && !this.rxPolarityNormal) {
      dtcsPrefix = "01";
    } else if (!this.txPolarityNormal && this.rxPolarityNormal) {
      dtcsPrefix = "10";
    } else if (!this.txPolarityNormal && !this.rxPolarityNormal) {
      dtcsPrefix = "11";
    }
    dtcsHex =  dtcsPrefix + dtcsHex.slice(2,6);
    return dtcsHex;
  }
}

class VFOIcom extends VFO {
  _currentModeIndex = 0;
  _currentFilterIndex = 0;
  _currentSplitValue = "00";
  _subBandVisible = false;
  _subBandHideTimer = null;
  _dataMode = 0;
  _splitMode = 0;

  // eventually make a scope data object?
  scopeData = [];
  scopeIsOn = false;
  scopeIsSending = false;

  constructor() {
    super();
  }
}

class Radio {
  _arrVFO = [];
  _objSMDeviceRouter;
  #activeInHMI = false;
  _powerOn = false;
  _poweringState = PoweringState.Off;
  _lastResponseDt = new Date(0);
  _ID = 0;
  #eventTarget = new EventTarget();
  radioType = Radio_Type.Generic;

  _voltage = 0;
  _amperage = 0;
  _afLevel = 0;

  // Global operate mode variables
  _operateMode = OperateMode.VFO; // "VFO" or "MEM"
  _memoryCH = "0001";   // default memory channel
  _toneValue = "00";    // "00" => no TONE, "11" => DUP-, "12" => DUP+
  // DELETE THIS: //_mode = "N/A";
  // DELETE THIS: //_filter = "N/A";

  _activeVFOIndex = 0;
  _inactiveVFOIndex = 1;
  _lastSend = new Date();

  get active() {return this.#activeInHMI;}
  set active(x) {this.#activeInHMI = x;}


  constructor(objSMDeviceRouter) {
    this._objSMDeviceRouter = objSMDeviceRouter;
    this._powerOn = false;
    this._poweringState = PoweringState.Off;
    this._lastResponseDt = new Date(0);

    // Global operate mode variables
    this._operateMode = "VFO"; // "VFO" or "MEM"
    this._memoryCH = "0001";   // default memory channel
    this._toneValue = "00";    // "00" => no TONE, "11" => DUP-, "12" => DUP+
    // DELETE THIS: //this._mode = "N/A";
    // DELETE THIS: //this._filter = "N/A";

    this._arrVFO[0] = new VFO();
    this._arrVFO[1] = new VFO();
    this._activeVFOIndex = 0;

    this._Id = Date.now();

  }

  initialize() { /* Send commmands to device to get intial settings */
  }

  addEventListener(eventName, callback) {

    this.#eventTarget.addEventListener(eventName, callback);
  }

  removeEventListener(eventName, callback) {

    this.#eventTarget.removeEventListener(eventName, callback);
  }

  dispatchEvent(customEvent) {

    this.#eventTarget.dispatchEvent(customEvent);
  }

}

class RadioIcom extends Radio {
  modeList = ["00", "01", "02", "03", "04", "05", "07", "08"];
  filterList = ["01", "02", "03"];

  #objSMPollRadioIcom;
  radioType = Radio_Type.Generic_Icom;

  get address() {return this._address;}
  set address(x) {this._address = x;}
  get polls() {return this.#objSMPollRadioIcom;}

  constructor(objSMDeviceRouter, address) {
    super(objSMDeviceRouter);
    this._Id = address;
    this._address = address;
    this._displayAddress = objSMDeviceRouter.displayAddress;

    this._currentModeIndex = 0;
    this._currentFilterIndex = 0;
    this._currentSplitValue = "00";
    this._subBandVisible = false;
    this._subBandHideTimer = null;
    this._dataMode = 0;
    // DELETE THIS: //this._splitMode = 0;

    // Setup VFOs...
    this._arrVFO[0] = new VFOIcom();
    this._arrVFO[1] = new VFOIcom();
    this._activeVFOIndex = 0;

    this.#objSMPollRadioIcom = new SMPollRadioIcom(this);


    this._objSMDeviceRouter.addEventListener('ready', (event) => {
      let strResponse = "shackmate.js::RadioIcom -> Heard this._objSMDeviceRouter ready event, ";
      strResponse += "initializing radio...";

      var e = new CustomEvent("rig_event", {detail: {rig: this, value: "socketOpen", objSMDeviceRouter: objSMDeviceRouter}});
      this.dispatchEvent(e);

      console_log(strResponse);
      this.initialize();
      this.#objSMPollRadioIcom.start();
    });

    this._objSMDeviceRouter.addEventListener('not ready', (event) =>{
      var e = new CustomEvent("rig_event", {detail: {rig: this, value: "socketClose", objSMDeviceRouter: objSMDeviceRouter}});
      this.dispatchEvent(e);
      this.#objSMPollRadioIcom.stop();
    });

    this._objSMDeviceRouter.addEventListener('WebSocket', (event) =>{
      var e = new CustomEvent("rig_event", {detail: {rig: this, value: "WebSocket", readyState: event.detail}});
      this.dispatchEvent(e);
    });



    this._objSMDeviceRouter.addEventListener(this.address, (event) =>{
      console_log("shackmate.js::RadioIcom -> Heard Event " + this.address);

      const decodedResponse = event.detail;
      if (decodedResponse.validMessage != undefined) {
        this.handleResponse(decodedResponse);            
      }
    });
  }

  sendCommand(command, boolPoll = false) {
    let a = this._address;
    let b = this._displayAddress;
    let c = command;
    let boolAddFE = false;
    let fe = "FE FE";
    let repeats = 0;

    if (command === "18 01") boolAddFE = true;
    if (boolAddFE) {
      switch (this._objSMDeviceRouter.baudrate) {
        case 115200:
          repeats = 150;
          break;
        case 57600:
          repeats = 75;
          break;
        case 38400:
          repeats = 50;
          break;
        case 19200:
          repeats = 25;
          break;
        case 9600:
          repeats = 13;
          break;
        case 4800:
          repeats = 7;
          break;
        default:
          repeats = 0;
      }
      for (let i = 0; i < repeats; i++) {
        fe += " FE"
      }
    }

    if (!c) return;
    let data = (`${fe} ${a} ${b} ${c} FD`);
    this._objSMDeviceRouter.send(data, boolPoll);
  }

  powerOn(boolPowerOn = true) {
    let command = "";

    if (boolPowerOn) {
      command = ("18 01");
      this._poweringState = PoweringState.TurningOn;
      var e = new CustomEvent("rig_event", {detail: {rig: this, value: PoweringState.TurningOn}});
      this.dispatchEvent(e);
      setTimeout(() => {this.initialize()}, 8000)
    } else {
      command = ("18 00");
      this._poweringState = PoweringState.TurningOff;
      var e = new CustomEvent("rig_event", {detail: {rig: this, value: PoweringState.TurningOff}});
      this.dispatchEvent(e);
      setTimeout(() => {
        var e = new CustomEvent("rig_event", {detail: {rig: this, value: "power", power: false}});
      this.dispatchEvent(e);
        this._powerOn = false;
        this._poweringState = PoweringState.Off;
      }, 4000);
    }

    console_log(`shackmate.js::RadioIcom.powerOn(${boolPowerOn})`);
    this.sendCommand(command);

    //arrRadio[rig_activeArrRadioIndex]._powerOn = powerOn;
  }

  sendFrequencyQuery() {

    this.sendCommand('03');
  }

  txOn(boolTX = true) {
    if (this._arrVFO[this._activeVFOIndex].tx) {
      this.sendCommand("1C 00 00"); // TX OFF
      this._arrVFO[this._activeVFOIndex].tx = false; // preemptive, polling should catch this too
    }
    else {
      this.sendCommand("1C 00 01"); // TX ON
      this._arrVFO[this._activeVFOIndex].tx = true; // preemptive, polling should catch this too
    }
  }

  send0FCommand() {
    this.sendCommand('0F');
  }

  sendDefaultMode() {
    let a = this._address;
    let b = this._displayAddress;
    let msg = (`FE FE ${a} ${b} 04 FD`).replace(/\s+/g, " ").trim();
    this._objSMDeviceRouter.send(msg);
  }

  static getFrequencyFromHex(bytesData) {
    let frequency = "";
    for (let i = bytesData.length - 1; i >= 0; i--) {
      frequency += bytesData[i];
    }
    return frequency;
  }

  handleResponse(decodedResponse) {
    /*
    console_log("bytesPreamble: ", bytesPreamble);
    console_log("bytesTo: ", bytesTo);
    console_log("bytesFrom: ", bytesFrom);
    console_log("bytesCommandNumber: ", bytesCommandNumber);
    console_log("bytesSubCommandNumber: ", bytesSubCommandNumber);
    console_log("bytesData: ", bytesData);
    console_log("bytesEndOfMessage: ", bytesEndOfMessage);
    */
  
    let currentVFO = this._arrVFO[this._activeVFOIndex];



    if ( (decodedResponse.bytesTo[0] == this._displayAddress 
            || decodedResponse.bytesTo[0] == "00")
         && decodedResponse.bytesFrom[0] == this._address) {


      // Rig is on so update this for the Power Indicator
      if (decodedResponse.bytesCommandNumber.length > 0 /*|| decodedResponse.bytesOK != "FA"*/) {
        this._lastResponseDt = new Date();
      }

      // Set power on indicator...
      if (decodedResponse.bytesCommandNumber.length == 0 && decodedResponse.bytesOK.length > 0) {
        if ((this._poweringState == PoweringState.TurningOn 
            || this._poweringState == PoweringState.TurningOff)
            && decodedResponse.bytesOK[0] == "FB") {
          if (this._poweringState == PoweringState.TurningOn) {
            this._poweringState = PoweringState.On;
            this._powerOn = true;
          } 
          else {
            this._poweringState = PoweringState.Off;
            this._powerOn = false;
          }
          var e = new CustomEvent("rig_event", {detail: {rig: this
                                                         , value: "power"
                                                         , power: this._powerOn}});
          this.dispatchEvent(e);
        }
        else {
          if (decodedResponse.bytesOK[0] != "FA" &&
                (
                   this._poweringState == PoweringState.TurningOff
                || this._poweringState == PoweringState.Unknown
                )
             ) {
            this._poweringState = PoweringState.On;
            this._powerOn = true;
            var e = new CustomEvent("rig_event", {detail: {rig: this
                                                           , value: "power"
                                                           , power: this._powerOn}});
            this.dispatchEvent(e);
          }
        }
        //this._lastResponseDt = new Date();  // this was causing a false positive that the rig was on
      }
      else {
        if (this._poweringState == PoweringState.TurningOn) {
          this._poweringState = PoweringState.On;
          this._powerOn = true;
          var e = new CustomEvent("rig_event", {detail: {rig: this
                                                         , value: "power"
                                                         , power: this._powerOn}});
          this.dispatchEvent(e);
        }
      }



      // Decide what to do based on response...
      switch (decodedResponse.bytesCommandNumber[0]) {
        case "00":
        case "03":
          let t = decodedResponse.bytesData;
          let freq = this.decodeFrequencyReversedBCD(t[0], t[1], t[2], t[3], t[4]);
          currentVFO._frequency = freq;
          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "freq", freq: freq}});
          this.dispatchEvent(e);
          break;

        case "01":
        case "04":
          let mode = "";
          for (let i = 0; i < this.modeList.length; i ++) {
            if (this.modeList[i] == decodedResponse.bytesData[0]) {
              currentVFO._currentModeIndex = i;
              break;
            }
          }
          switch (decodedResponse.bytesData[0]) {
            case "00":
              mode = "LSB";
              break;
            case "01":
              mode = "USB";
              break;
            case "02":
              mode = "AM";
              break;
            case "03":
              mode = "CW";
              break;
            case "04":
              mode = "RTTY";
              break;
            case "05":
              mode = "FM";
              break;
            case "07":
              mode = "CW-R";
              break;
            case "08":
              mode = "RTTY-R";
              break;
          }
          
          currentVFO._mode = mode;
          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "mode", mode: mode}});
          this.dispatchEvent(e);


          let filter = "";
          for (let i = 0; i < this.filterList.length; i ++) {
            if (this.filterList[i] == decodedResponse.bytesData[1]) {
              currentVFO._currentFilterIndex = i;
              break;
            }
          }
          switch (decodedResponse.bytesData[1]) {
            case "01":
              filter = "FIL1";
              break;
            case "02":
              filter = "FIL2";
              break;
            case "03":
              filter = "FIL3";
              break;
          }
          currentVFO._filter = filter;
          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "filter", filter: filter}});
          this.dispatchEvent(e);
          break;

        case "0F":
          let split0F = false;
          let simplex0F = true;
          let duplexUp0F = false;
          let duplexDown0F = false;

          // Determine current state (Split Mode will override duplex settings at the radio)
          switch(decodedResponse.bytesData[0]) {
            case "00":
              split0F = false;
              break;

            case "01":
              split0F = true;
              duplexDown0F = false ;
              duplexUp0F = false;
              break;

            case "11":
              duplexDown0F = true ;
              simplex0F = false;
              split0F = false;
              break;

            case "12":
              duplexUp0F = true;
              simplex0F = false;
              split0F = false;
              break;
          }

          // Update VFO...
          currentVFO._splitMode = (split0F) ? 1 : 0;
          currentVFO._split = split0F;
          currentVFO.simplex = simplex0F;
          currentVFO.duplexUp = duplexUp0F;
          currentVFO.duplexDown = duplexDown0F;

          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "split", split: split0F}});
          this.dispatchEvent(e);
          break;

        case "14":
          switch (decodedResponse.bytesSubCommandNumber[0]) {
            case "01": // AF Level
              const arrAfLevel = decodedResponse.bytesData;
              let afLevel = arrAfLevel[0] + arrAfLevel[1];
              this._afLevel = Number(afLevel);
              let afPercentage = this._afLevel / 255.0 * 100;

              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "afLevel", afLevel: afLevel}});
              this.dispatchEvent(e);
              break;

            default:
              console_warn();
              break;
          }
          break;

        case "15":
          switch (decodedResponse.bytesSubCommandNumber[0]) {
            case "01": // Squelch
              let squelch = decodedResponse.bytesData[0];
              currentVFO._squelch = (squelch == "01") ? true : false;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "squelch", squelch: squelch}});
              this.dispatchEvent(e);
              break;
            case "02": // S Meter
              let smeter = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              currentVFO._smeter = smeter;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "smeter", smeter: smeter}});
              this.dispatchEvent(e);
              break;
            case "11": // PO
              let pometer = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              currentVFO._pometer = pometer;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "pometer", pometer: pometer}});
              this.dispatchEvent(e);
              break;
            case "12": // SWR
              let swrmeter = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              currentVFO._swrmeter = swrmeter;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "swrmeter", swrmeter: swrmeter}});
              this.dispatchEvent(e);
              break;
            case "13": // ALC
              let alc = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              currentVFO._alc = alc;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "alc", alc: alc}});
              this.dispatchEvent(e);
              break;
            case "14": // COMP
              let comp = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              currentVFO._comp = comp;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "comp", comp: comp}});
              this.dispatchEvent(e);
              break;
            case "15": // Voltage
              let voltage = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;
              this._voltage = voltage;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "voltage", voltage: voltage}});
              this.dispatchEvent(e);
              break;
            case "16": // Current
              // The ICOM IC-7300 typically draws 1.25 amps of current when receiving (Rx) with maximum 
              // audio output. In standby mode, the current draw is around 0.9 amps. 

              let minRxCurrent = 0.9;
              let maxRxCurrent = 1.25;

              switch(this.radioType) {
                case Radio_Type.IC_7300:
                  minRxCurrent = 0.9;
                  maxRxCurrent = 1.25;
                  break;
                case Radio_Type.IC_9700:
                  minRxCurrent = 1.2;
                  maxRxCurrent = 1.8;
                  break;
                default: 
                  console_warn("shackmate.js::RadioIcom.handleResponse() - Failure determining model for current draw");                  
                  break;
              }

              let amperage = decodedResponse.bytesData[0] * 100 + decodedResponse.bytesData[1] * 1;

              // If value is 0, determine based on AF Level...
              if (amperage == 0) {
                let squelchModifier = (this._arrVFO[this._activeVFOIndex]._squelch) ? 1 : 0;
                amperage = minRxCurrent + ( ( (this._afLevel / 255.0) * (maxRxCurrent - minRxCurrent) ) * squelchModifier );
                amperage = amperage * 9.7;
              }

              this._amperage = amperage;
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "amperage", amperage: amperage}});
              this.dispatchEvent(e);
              break;

          }
          break;

        case "16":
          switch (decodedResponse.bytesSubCommandNumber[0]) {
            case "42": // TX Tone
                if(this.radioType == Radio_Type.IC_7300) {
                  switch(decodedResponse.bytesData[0]) {
                    case "00": // Off
                      currentVFO.txToneEnabled = false;
                      break;
                    case "01": // On
                      currentVFO.txToneEnabled = true;
                      break;
                  }
                  var e = new CustomEvent("rig_event", {detail: {rig: this, value: "tone", currentVFO: currentVFO}});
                  this.dispatchEvent(e);
                }
                break;

            case "43": // RX TSQL
                if(this.radioType == Radio_Type.IC_7300) {
                  switch(decodedResponse.bytesData[0]) {
                    case "00": // Off
                      currentVFO.rxToneEnabled = false;
                      break;
                    case "01": // On
                      currentVFO.rxToneEnabled = true;
                      break;
                  }
                var e = new CustomEvent("rig_event", {detail: {rig: this, value: "tone", currentVFO: currentVFO}});
                this.dispatchEvent(e);
              }
              break;

            case "5D": // Tone / DTCS Configuration (IC-9700)
              const mode165D = decodedResponse.bytesData[0];
              switch (mode165D) {
                case "00":
                  currentVFO.txToneEnabled = false;
                  currentVFO.rxToneEnabled = false;
                  currentVFO.txDtcsEnabled = false;
                  currentVFO.rxDtcsEnabled = false;
                  break;
                case "01":
                  currentVFO.txToneEnabled = true;
                  currentVFO.rxToneEnabled = false;
                  currentVFO.txDtcsEnabled = false;
                  currentVFO.rxDtcsEnabled = false;
                  break;
                case "02":
                  currentVFO.txToneEnabled = false;
                  currentVFO.rxToneEnabled = true;
                  currentVFO.txDtcsEnabled = false;
                  currentVFO.rxDtcsEnabled = false;
                  break;
                case "03":
                  currentVFO.txToneEnabled = false;
                  currentVFO.rxToneEnabled = false;
                  currentVFO.txDtcsEnabled = true;
                  currentVFO.rxDtcsEnabled = true;
                  break;
                case "06":
                  currentVFO.txToneEnabled = false;
                  currentVFO.rxToneEnabled = false;
                  currentVFO.txDtcsEnabled = true;
                  currentVFO.rxDtcsEnabled = false;
                  break;
                case "07":
                  currentVFO.txToneEnabled = true;
                  currentVFO.rxToneEnabled = false;
                  currentVFO.txDtcsEnabled = false;
                  currentVFO.rxDtcsEnabled = true;
                  break;
                case "08":
                  currentVFO.txToneEnabled = false;
                  currentVFO.rxToneEnabled = true;
                  currentVFO.txDtcsEnabled = true;
                  currentVFO.rxDtcsEnabled = false;
                  break;
                case "09":
                  currentVFO.txToneEnabled = true;
                  currentVFO.rxToneEnabled = true;
                  currentVFO.txDtcsEnabled = false;
                  currentVFO.rxDtcsEnabled = false;
                  break;
              }

              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "tone", currentVFO: currentVFO}});
              this.dispatchEvent(e);
              break;
          }          
          break;

        case "1A":
          switch(decodedResponse.bytesSubCommandNumber[0]) {
            case "01":
              //bData:['03','01','00','40','07','07','00','01','01','10','00','08','85','00','08','85']
              let bandIndex = Number(decodedResponse.bytesData[0]) - 1;
              let stackIndex = Number(decodedResponse.bytesData[1]) - 1;
              let freq = this.decodeFrequencyReversedBCD(decodedResponse.bytesData[2]
                                                   , decodedResponse.bytesData[3]
                                                   , decodedResponse.bytesData[4]
                                                   , decodedResponse.bytesData[5]
                                                   , decodedResponse.bytesData[6]);
              this.bandStackingList[bandIndex][stackIndex] = freq;
              break;

            case "06":
              let dataMode = ""
              switch (decodedResponse.bytesData[0]) {
                case "00":
                  dataMode = "";
                  currentVFO._dataMode = 0;
                  currentVFO._data = false;
                  break;
                case "01":
                  dataMode = "-D";
                  currentVFO._dataMode = 1;
                  currentVFO._data = true;
                  break;
              }
    
              var e = new CustomEvent("rig_event", {detail: {rig: this
                                                             , value: "dataMode"
                                                             , dataMode: currentVFO._dataMode}});
              this.dispatchEvent(e);

              let filter = "";
              switch (decodedResponse.bytesData[1]) {
                case "01":
                  filter = "FIL1";
                  break;
                case "02":
                  filter = "FIL2";
                  break;
                case "03":
                  filter = "FIL3";
                  break;
              }
              if (filter != "") {
                currentVFO._filter = filter;
                var e = new CustomEvent("rig_event", {detail: {rig: this
                                                               , value: "filter"
                                                               , filter: filter}});
                this.dispatchEvent(e);
              }
              break;
          }
          break;

        case "1B":
          let data1B = decodedResponse.bytesData;
          switch(decodedResponse.bytesSubCommandNumber[0]) {
            case "00": // TX Tone
              if (currentVFO.txToneEnabled) {
                let tone1B00 = data1B[0] + data1B[1] + data1B[2];
                currentVFO.tone = tone1B00;
              }
              break;

            case "01": // RX Tone
              if (currentVFO.rxToneEnabled) {
                let tsql1B00 = data1B[0] + data1B[1] + data1B[2];
                currentVFO.tsql = tsql1B00;
              }
              break;
 
            case "02": // DTCS
              let dtcs1B00 = data1B[0] + data1B[1] + data1B[2];
              switch(data1B[0]) {
                case "00":
                  currentVFO.txPolarityNormal = true;
                  currentVFO.rxPolarityNormal = true;
                  break;
                case "01":
                  currentVFO.txPolarityNormal = true;
                  currentVFO.rxPolarityNormal = false;
                  break;
                case "10":
                  currentVFO.txPolarityNormal = false;
                  currentVFO.rxPolarityNormal = true;
                  break;
                case "11":
                  currentVFO.txPolarityNormal = false;
                  currentVFO.rxPolarityNormal = false;
                  break;
              }
              currentVFO.dtcs = dtcs1B00;
              break;
          }
          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "tone", currentVFO: currentVFO}});
          this.dispatchEvent(e);
          break;

        case "1C":
          switch(decodedResponse.bytesSubCommandNumber[0]) {
            case "00":  //  TX/RX
              switch (decodedResponse.bytesData[0]) {
                case "00":
                  // RX mode
                  currentVFO.tx = false;
                  var e = new CustomEvent("rig_event", {detail: {rig: this, value: "RX"}});
                  this.dispatchEvent(e);
                  break;
                case "01":
                  // TX mode
                  currentVFO.tx = true;
                  var e = new CustomEvent("rig_event", {detail: {rig: this, value: "TX"}});
                  this.dispatchEvent(e);
                  break;
              }
              break;

            case "01":  //  Ant Tuner on/off
            
              break;
          }
          break;

        case "25":
          //Determine if Active or Inactive VFO Data...
          switch (decodedResponse.bytesData[0]) {
            case "00":
              // Active VFO
              currentVFO = this._arrVFO[this._activeVFOIndex];
              break;
            case "01":
              // Inactive VFO
              currentVFO = this._arrVFO[(this._activeVFOIndex + 1) % 2];
              break;
          }

          let t25 = decodedResponse.bytesData;
          let freq25 = this.decodeFrequencyReversedBCD(t25[1], t25[2], t25[3], t25[4], t25[5]);
          currentVFO._frequency = freq25;

          var e = new CustomEvent("rig_event", {detail: {rig: this, value: "freq", freq: freq25}});
          this.dispatchEvent(e);
          break;

        case "26":
          let boolSendEvent26 = false;
          //Determine if Active or Inactive VFO Data...
          switch (decodedResponse.bytesData[0]) {
            case "00":
              // Active VFO
              currentVFO = this._arrVFO[this._activeVFOIndex];
              boolSendEvent26 = true;
              break;
            case "01":
              // Inactive VFO
              currentVFO = this._arrVFO[(this._activeVFOIndex + 1) % 2];
              break;
          }

          // MODE
          let mode26 = "";
          for (let i = 0; i < this.modeList.length; i ++) {
            if (this.modeList[i] == decodedResponse.bytesData[1]) {
              currentVFO._currentModeIndex = i;
              break;
            }
          }
          switch (decodedResponse.bytesData[1]) {
            case "00":
              mode26 = "LSB";
              break;
            case "01":
              mode26 = "USB";
              break;
            case "02":
              mode26 = "AM";
              break;
            case "03":
              mode26 = "CW";
              break;
            case "04":
              mode26 = "RTTY";
              break;
            case "05":
              mode26 = "FM";
              break;
            case "07":
              mode26 = "CW-R";
              break;
            case "08":
              mode26 = "RTTY-R";
              break;
          }
          
          currentVFO._mode = mode26;
          if (boolSendEvent26) {
            var e = new CustomEvent("rig_event", {detail: {rig: this, value: "mode", mode: mode26}});
            this.dispatchEvent(e);
          }

          // DATA
          let dataMode26 = ""
          switch (decodedResponse.bytesData[2]) {
            case "00":
              dataMode26 = "";
              currentVFO._dataMode = 0;
              currentVFO._data = false;
              break;
            case "01":
              dataMode26 = "-D";
              currentVFO._dataMode = 1;
              currentVFO._data = true;
              break;
          }
          if (boolSendEvent26) {
            var e = new CustomEvent("rig_event", {detail: {rig: this
                                                           , value: "dataMode"
                                                           , dataMode: currentVFO._dataMode}});
            this.dispatchEvent(e);
          }

          // FILTER
          let filter26 = "";
          for (let i = 0; i < this.filterList.length; i ++) {
            if (this.filterList[i] == decodedResponse.bytesData[3]) {
              currentVFO._currentFilterIndex = i;
              break;
            }
          }
          switch (decodedResponse.bytesData[3]) {
            case "01":
              filter26 = "FIL1";
              break;
            case "02":
              filter26 = "FIL2";
              break;
            case "03":
              filter26 = "FIL3";
              break;
          }


          if (boolSendEvent26) {
            if (filter26 != "") {
              currentVFO._filter = filter26;
              var e = new CustomEvent("rig_event", {detail: {rig: this
                                                             , value: "filter"
                                                             , filter: filter26}});
              this.dispatchEvent(e);
            }
          }

          break;

        case "27":
          /*
          Received: FE FE AA 94 27 00 00 01 11 00 00 90 09 18 00 00 50 00 00 00 00 FD
          Received: FE FE AA 94 27 00 00 02 11 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ... FD
                                      00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 ...
          */
          switch(decodedResponse.bytesSubCommandNumber[0]) {
            case "00": // Scope Data
              let t27 = decodedResponse.bytesData;

              const segmentNumber = t27[1];
              const totalSegments = t27[2];
              if (segmentNumber == "01") {
                const scopeMode = t27[3];
                const freq27 = this.decodeFrequencyReversedBCD(t27[4], t27[5], t27[6], t27[7], t27[8]);
                const rangeInfo = t27[9];
              }
              else {
                if (parseInt(segmentNumber) > 1) {
                  const currentInterval = parseInt(segmentNumber);
                  const intervalSize = 50;
                  const startingElement = ((currentInterval - 2) * intervalSize);

                  for (let i = 3; i < t27.length; i++) {
                    currentVFO.scopeData[startingElement + (i - 3)] = t27[i];
                  }
                }
                if (parseInt(segmentNumber) == 11) {
                  var e = new CustomEvent("rig_event", {detail: {rig: this, value: "scopeData", scopeData: Array.from(currentVFO.scopeData)}});
                  this.dispatchEvent(e);
                }
              }
              break;

            case "10": // Scope is On
              switch(decodedResponse.bytesData[0]) {
                case "00":
                  currentVFO.scopeIsOn = false;
                  break;
                case "01":
                  currentVFO.scopeIsOn = true;
                  break;
              }
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "scopeIsOn", scopeIsOn: currentVFO.scopeIsOn}});
              this.dispatchEvent(e);
              break;

            case "11": // Scope is sending Data
              switch(decodedResponse.bytesData[0]) {
                case "00":
                  currentVFO.scopeIsSending = false;
                  break;
                case "01":
                  currentVFO.scopeIsSending = true;
                  break;
              }
              var e = new CustomEvent("rig_event", {detail: {rig: this, value: "scopeIsSending", scopeIsSending: currentVFO.scopeIsSending}});
              this.dispatchEvent(e);
              break;
          }
          break;
      } // switch
    } // if
  }

  encodeFrequencyReversedBCD(decimalFrequency) {
    let arrFreq = [5];
    decimalFrequency = "0000000000" + decimalFrequency;
    decimalFrequency = decimalFrequency.replace(".", "");
    decimalFrequency = decimalFrequency.replace(".", "");

    arrFreq[0] = decimalFrequency.at(decimalFrequency.length - 2) + decimalFrequency.at(decimalFrequency.length - 1);
    arrFreq[1] = decimalFrequency.at(decimalFrequency.length - 4) + decimalFrequency.at(decimalFrequency.length - 3);
    arrFreq[2] = decimalFrequency.at(decimalFrequency.length - 6) + decimalFrequency.at(decimalFrequency.length - 5);
    arrFreq[3] = decimalFrequency.at(decimalFrequency.length - 8) + decimalFrequency.at(decimalFrequency.length - 7);
    arrFreq[4] = decimalFrequency.at(decimalFrequency.length - 10) + decimalFrequency.at(decimalFrequency.length - 9);

    return arrFreq;
  }

  decodeFrequencyReversedBCD(b5, b6, b7, b8, b9) {
    let arr = [b9, b8, b7, b6, b5], joined = arr.join("");
    while (joined.length < 10) { joined = "0" + joined; }
    let front = joined.substring(0, 4),
        mid = joined.substring(4, 7),
        last = joined.substring(7);
    front = front.replace(/^0+/, '');
    if (front === "") front = "0";
    return front + "." + mid + "." + last;
  }

  setFrequency(decimalFrequency) {
    let arrFreq = this.encodeFrequencyReversedBCD(decimalFrequency);
    let strFreq = arrFreq[0];
    strFreq += " " + arrFreq[1];
    strFreq += " " + arrFreq[2];
    strFreq += " " + arrFreq[3];
    strFreq += " " + arrFreq[4];

    this.sendCommand("25 00 " + strFreq); // ????turn off DATA mode
  }

  startScope() {
    this.sendCommand("27 10 01");
    this.sendCommand("27 11 01");
    this.sendCommand("27 10");
    this.sendCommand("27 11");
  }

  stopScope() {
    this.sendCommand("27 11 00");
    this.sendCommand("27 10");
    this.sendCommand("27 11");
  }

  decodeMode(h) {
    switch (h) {
      case "00": return "LSB";
      case "01": return "USB";
      case "02": return "AM";
      case "03": return "CW";
      case "04": return "RTTY";
      case "05": return "FM";
      case "07": return "CW-R";
      case "08": return "RTTY-R";
      case "17": return "DV";
      case "22": return "DD";
      default:   return "Unknown";
    }
  }

  updateMode(mode, filter, data, poll = true) {
    let v = this._arrVFO[this._activeVFOIndex],
        m = this.modeList[v._currentModeIndex],
        f = this.filterList[v._currentFilterIndex],
        d = v._dataMode;
    if (mode != undefined) m = mode;
    if (filter != undefined) f = filter;
    if (data != undefined) d = data;


    let boolModeChange = (m != this.modeList[v._currentModeIndex]);
    let boolFilterChange = (f != this.filterList[v._currentFilterIndex]);
    let boolDataChange = (d != v._dataMode);

    this.sendCommand(`26 00 ${m} 0${d} ${f}`);

    if (poll) {
      this.sendCommand('26 00');
    }
  }

  requestRepeaterDetails() { // Sends commands to update VFO with tone/duplex settings
    switch(this.radioType) {
      case Radio_Type.IC_9700:
        this.sendCommand("16 5D"); // Get Tone/DTCS Configuration (IC-9700)
        break;

      case Radio_Type.IC_7300:
      default:
        this.sendCommand("16 42"); // Get Tone Configuration (IC-7300)
        this.sendCommand("16 43"); // Get Tone Configuration (IC-7300)
        break;
    }
    this.sendCommand("1B 00"); // Get RX Tone    
    this.sendCommand("1B 01"); // Get TX Tone
    switch(this.radioType) {
      case Radio_Type.IC_9700:
        this.sendCommand("1B 02"); // Get DTCS
        break;

      case Radio_Type.IC_7300:
      default:
        break;
    }
    this.send0FCommand();      // Get Simplex/Duplex
  }

  sendToneValues() {
    const vfo = this._arrVFO[this._activeVFOIndex];

    if (vfo.txToneEnabled) {
      this.sendCommand("1B 00" + vfo.toneHex);
      this.sendCommand("1B 00");
    }

    if (vfo.rxToneEnabled) {
      this.sendCommand("1B 01" + vfo.tsqlHex);
      this.sendCommand("1B 01");
    }

    if (vfo.txDtcsEnabled || vfo.rxDtcsEnabled) {
      this.sendCommand("1B 02" + vfo.dtcsHex);
      this.sendCommand("1B 02");
    }


  }

  changeToneValue(boolNext, boolTxSide) {
    const vfo = this._arrVFO[this._activeVFOIndex];

    let newValue = "";

    if (boolTxSide) { // TX Side
      if (vfo.txToneEnabled) { // Tone
        newValue = (boolNext) ? vfo.nextToneHex : vfo.previousToneHex;
        this.sendCommand("1B 00" + newValue);
        this.sendCommand("1B 00");
      }
      else if (vfo.txDtcsEnabled) { //DTCS
        newValue = (boolNext) ? vfo.nextDtcsHex : vfo.previousDtcsHex;
        this.sendCommand("1B 02" + newValue);
        this.sendCommand("1B 02");
      }
    }
    else { // RX Side
      if (vfo.rxToneEnabled) { // TSQL
        newValue = (boolNext) ? vfo.nextTsqlHex : vfo.previousTsqlHex;
        this.sendCommand("1B 01" + newValue);
        this.sendCommand("1B 01");
      }
      else if (vfo.rxDtcsEnabled) { // DTCS
        newValue = (boolNext) ? vfo.nextDtcsHex : vfo.previousDtcsHex;
        this.sendCommand("1B 02" + newValue);
        this.sendCommand("1B 02");
      }
    }   
  }

  changeDuplex(boolDuplex, boolShiftUp) {
    const vfo = this._arrVFO[this._activeVFOIndex];

    if (boolDuplex) {     // Duplex Mode
      if (boolShiftUp) {  // DUP +
        this.sendCommand("0F 12");
      }
      else {              // DUP -
        this.sendCommand("0F 11");
      }
    }
    else {                // Simplex Mode
      this.sendCommand("0F 10");
    }

    this.send0FCommand();
  }

  changeToneType(toneType, boolTxSide) {
    const vfo = this._arrVFO[this._activeVFOIndex];

    let newTxTone = vfo.txToneEnabled;
    let newRxTone = vfo.rxToneEnabled;
    let newTxDtcs = vfo.txDtcsEnabled;
    let newRxDtcs = vfo.rxDtcsEnabled;


    switch(toneType) {
      case "off":
        if (boolTxSide) {
          newTxTone = false;
          newTxDtcs = false;
        }
        else {
          newRxTone = false;
          newRxDtcs = false;
        }
        break;

      case "tone":
        if (boolTxSide) {
          newTxTone = true;
          newTxDtcs = false;
        }
        else {
          newRxTone = true;
          newRxDtcs = false;
        }
        break;

      case "dtcs":
        if (boolTxSide) {
          newTxTone = false;
          newTxDtcs = true;
        }
        else {
          newRxTone = false;
          newRxDtcs = true;
        }
        break;
    }    

    // Handle new Tone/DTCS setup
    if (!newTxTone && !newRxTone && !newTxDtcs && !newRxDtcs) {     // TX OFF   RX OFF
      switch(this.radioType) {
        case Radio_Type.IC_9700:
          this.sendCommand("16 5D 00");
          this.sendCommand("16 5D");
          break;

        case Radio_Type.IC_7300:
        default:
          this.sendCommand("16 42 00");
          this.sendCommand("16 43 00");
          this.sendCommand("16 42");
          this.sendCommand("16 43");
          break;
      }
    }
    else if (newTxTone && !newRxTone && !newTxDtcs && !newRxDtcs) { // TX TONE  RX OFF
      switch(this.radioType) {
        case Radio_Type.IC_9700:
          this.sendCommand("16 5D 01");
          this.sendCommand("16 5D");
          break;

        case Radio_Type.IC_7300:
        default:
          this.sendCommand("16 42 01");
          this.sendCommand("16 43 00");
          this.sendCommand("16 42");
          this.sendCommand("16 43");
          break;
      }
    }
    else if (!newTxTone && newRxTone && !newTxDtcs && !newRxDtcs) { // TX OFF   RX TONE
      switch(this.radioType) {
        case Radio_Type.IC_9700:
          this.sendCommand("16 5D 02");
          this.sendCommand("16 5D");
          break;

        case Radio_Type.IC_7300:
        default:
          this.sendCommand("16 42 00");
          this.sendCommand("16 43 01");
          this.sendCommand("16 42");
          this.sendCommand("16 43");
          break;
      }
    }
    else if (!newTxTone && !newRxTone && newTxDtcs && newRxDtcs) {  // TX DTCS  RX DTCS
      this.sendCommand("16 5D 03");
      this.sendCommand("16 5D");
    }
    else if (!newTxTone && !newRxTone && newTxDtcs && !newRxDtcs) { // TX DTCS  RX OFF
      this.sendCommand("16 5D 06");
      this.sendCommand("16 5D");
    }
    else if (newTxTone && !newRxTone && !newTxDtcs && newRxDtcs) {  // TX TONE  RX DTCS
      this.sendCommand("16 5D 07");
      this.sendCommand("16 5D");
    }
    else if (!newTxTone && newRxTone && newTxDtcs && !newRxDtcs) {  // TX DTCS  RX TONE
      this.sendCommand("16 5D 08");
      this.sendCommand("16 5D");
    }
    else if (newTxTone && newRxTone && !newTxDtcs && !newRxDtcs) {  // TX TONE  RX TONE
      switch(this.radioType) {
        case Radio_Type.IC_9700:
          this.sendCommand("16 5D 09");
          this.sendCommand("16 5D");
          break;

        case Radio_Type.IC_7300:  // Only one or the other can be active
          if (vfo.txToneEnabled) {
            this.sendCommand("16 43 01");
          }
          else {
            this.sendCommand("16 42 01");
          }
          this.sendCommand("16 42");
          this.sendCommand("16 43");
          break;

        default:
          this.sendCommand("16 42 01");
          this.sendCommand("16 43 01");
          this.sendCommand("16 42");
          this.sendCommand("16 43");
          break;
      }
    }
    // Catch invalid cases...
    else if (!newTxTone && !newRxTone && !newTxDtcs && newRxDtcs) {
      console_warn("Not able use RX DTCS only, select different option!")
      // old state: TX OFF !RX DTCS   new state: TX DTCS RX DTCS
      if (!vfo.txToneEnabled && !vfo.txDtcsEnabled) {
        this.sendCommand("16 5D 03");
        this.sendCommand("16 5D");
      }
      // old state: !TX OFF RX DTCS   new state: TX OFF RX OFF
      else if (vfo.txToneEnabled || vfo.txDtcsEnabled) {
        this.sendCommand("16 5D 00");
        this.sendCommand("16 5D");
      }
      else {
        console_error("Not able use RX DTCS only, select different option!")
        this.sendCommand("16 5D");
      }
    }
  }

  changeDtcsPolarity(boolTxSide) {
    const vfo = this._arrVFO[this._activeVFOIndex];

    if (boolTxSide) {
      vfo.txPolarityNormal = !vfo.txPolarityNormal;
    }
    else {
      vfo.rxPolarityNormal = !vfo.rxPolarityNormal;
    }
    this.sendCommand("1B 02" + vfo.dtcsHex);
    this.sendCommand("1B 02");
  }

  initialize() { /* Send commmands to device to get intial settings */
    console_log("RadioIcom::initialize() sending 03...");  // Frequnecy
    this.sendCommand("03");
    
    console_log("RadioIcom::initialize() sending 04...");  // Mode
    this.sendCommand("04");
    
    console_log("RadioIcom::initialize() sending 1A 06...");  // Data
    this.sendCommand("1A 06");

    console_log("RadioIcom::initialize() sending 0F...");  // Split
    this.sendCommand("0F");

    console_log("RadioIcom::initialize() sending 07...");  // VFO
    this.sendCommand("07 00");
  }
}

class RadioIcom7300 extends RadioIcom {
  bandStackingList = [["1.800.000","1.800.000","1.800.000"]
                     ,["3.500.000","3.500.000","3.500.000"]
                     ,["7.000.000","7.000.000","7.000.000"]
                     ,["10.000.000","10.000.000","10.000.000"]
                     ,["14.000.000","14.000.000","14.000.000"]
                     ,["18.068.000","18.068.000","18.068.000"]
                     ,["21.000.000","21.000.000","21.000.000"]
                     ,["24.890.000","24.890.000","24.890.000"]
                     ,["28.000.000","28.000.000","28.000.000"]
                     ,["53.000.000","53.000.000","53.000.000"]
                     ];
  radioType = Radio_Type.IC_7300;

  constructor(objSMDeviceRouter, port, displayAddress) {
    super(objSMDeviceRouter, port, displayAddress);

    this._type = Radio_Type.IC_7300;

    // Global operate mode variables
    this._operateMode = "VFO"; // "VFO" or "MEM"
    this._memoryCH = "0001";   // default memory channel
    this._toneValue = "00";    // "00" => no TONE, "11" => DUP-, "12" => DUP+
  }


}

class RadioIcom9700 extends RadioIcom {
  modeList = ["00", "01", "02", "03", "04", "05", "07", "08", "17", "22"];
  bandStackingList = [["144.000.000","144.000.000","144.000.000"]
                             ,["430.000.000","430.000.000","430.000.000"]
                             ,["1240.000.000","1240.000.000","1240.000.000"]
                             ];
  radioType = Radio_Type.IC_9700;

  constructor(objSMDeviceRouter, port, displayAddress) {
    super(objSMDeviceRouter, port, displayAddress);

    this._type = Radio_Type.IC_9700;

    // Global operate mode variables
    this._operateMode = "VFO"; // "VFO" or "MEM"
    this._memoryCH = "0001";   // default memory channel
    this._toneValue = "00";    // "00" => no TONE, "11" => DUP-, "12" => DUP+
  }

  // Gets radio callsign...
  sendReceiverIDCommand() {
    // Eventually update to set callsign...
    this.sendCommand("1F 00");
  }

}

class SMRotor extends SMDeviceRouter {
  constructor(name, type, url) {
    super(url);
    this.name = name;
    this.type = type;
  }
}

class SMAntenna extends SMDeviceRouter {
  constructor(name, type, url) {
    super(url);
    this.name = name;
    this.type = type;
  }
}

class SMSwitch extends SMDeviceRouter {
  constructor(name, type, url) {
    super(url);
    this.name = name;
    this.type = type;
  }
}

