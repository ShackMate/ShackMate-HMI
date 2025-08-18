<!DOCTYPE html>
<html>
<head>
  <title> HBC Shack Mate </title>
  <!-- Head - links and meta -->
  <link rel="stylesheet" href="w3.css">
  <link rel="stylesheet" href="display.css">
  <link rel="stylesheet" href="rig.css">
  <link rel="stylesheet" href="antenna.css">
  <link rel="stylesheet" href="rotor.css">
  <style type="text/css">  /* Indicators color and animation */
    .blinking-power-indicator-on {
      animation: blink-green 300ms infinite;
    }
    @keyframes blink-green {
      from {fill: black;}
      to {fill: #ccff66;}
    }
    .blinking-power-indicator-off {
      animation: blink-red 300ms infinite;
    }
    @keyframes blink-red {
      from {fill: black;}
      to {fill: #be0000;}
    }
    .solid-power-indicator-on {
      animation: none;
      fill: #ccff66;
    }
    .solid-power-indicator-off {
      animation: none;
      fill: #be0000;
    }
    .blinking-text {
      animation: blink 1s infinite; /* 1s duration, infinite loop */
      fill: #ccff66;
    }
    @keyframes blink {
      0% { opacity: 1; }
      50% { opacity: 0; }
      100% { opacity: 1; }
    }

  </style>
  <meta charset="UTF-8">
  <script>
    const params = new Proxy(new URLSearchParams(window.location.search), {
      get: (searchParams, prop) => searchParams.get(prop),
    });
    // Get the value of "some_key" in eg "https://example.com/?some_key=some_value"
    // let value = params.some_key; // "some_value"
    let DEBUG = (params.debug == "true") ? true : false;

    function console_log(x) {if (DEBUG) {console.log(x);}}
    function console_info(x) {if (DEBUG) {console.info(x);}}
    function console_warn(x) {if (DEBUG) {console.warn(x);}}
    function console_error(x) {if (DEBUG) {console.error(x);}}
  </script>
  <script src="shackmate.js"></script>
  <script src="rig.js"></script>
  <!-- Add/activate scripts as development proceeds -->
  <!--<script src="antenna.js"></script>-->
  <!--<script src="rotor.js"></script>-->
  <script type="text/javascript">
    var hmi_header_rig = "N/A";
    var hmi_header_antenna = "N/A";
    var hmi_header_rotator = "N/A";
    var hmi_header_datetime = "N/A";

    var hmi_display_address = "EE";

    var refreshRate = 100;

    var hmi_touch_start_button;
    var hmi_touch_stop_button;
    var hmi_touch_start_time;
    var hmi_touch_stop_time;

    var hmi_footer_selected = "";

    //let hmi_data = loadJsonData('./config.json');
    let objSMDeviceRouter;
    let arrRadio = [];
    let objHmiRigsPage;
    let objHardwareControls;
    let hmi_boolPageLoaded = false;

    let hmi_data = loadJsonData('./config.json').then(data => {
      if (data) {
        console_log("JSON data loaded:", data);
        objSMDeviceRouter = new SMDeviceRouter(data.socket_server, hmi_data.display_address);

        arrRadio = [
            new RadioIcom9700(objSMDeviceRouter, "A2")
          ,new RadioIcom7300(objSMDeviceRouter, "94")
        ]

        objHmiRigsPage = new hmiRigsPage(arrRadio);

        objHardwareControls = new HardwareControls();

        objHmiRigsPage.updateRigDisplaySelectionButtons();
        for (let i = 0; i < objHmiRigsPage.arrDisplay.length; i++) {
          objHmiRigsPage.arrDisplay[i].updateElement("ALL");
        }

        const intervalTapRig = setInterval(() => {
          if (hmi_boolPageLoaded) {
            if (hmi_footer_selected == "") {
              hmi_touch_start("rig");
              hmi_touch_stop("rig");
            }

            clearInterval(intervalTapRig);
          }
        }, 500);

      }
    });

    window.addEventListener('DOMContentLoaded', () => {
      hmi_boolPageLoaded = true;
    });


    window.addEventListener('DOMContentLoaded', () => {

      // Utility: Attach pointer-based long press to a button.
      // shortPressFn is called if released before 750ms is up,
      // longPressFn is called if the user holds for 750ms.
      function hmi_addLongPress(button, longPressFn, shortPressFn) {
        let holdTimeout = null;
        let holdFired = false;
        button.addEventListener("pointerdown", () => {
          holdFired = false;
          holdTimeout = setTimeout(() => {
            holdFired = true;
            longPressFn();
          }, 750);
        });
        button.addEventListener("pointerup", () => {
          if (holdTimeout) {
            clearTimeout(holdTimeout);
            holdTimeout = null;
            if (!holdFired) {
              shortPressFn();
            }
          }
        });
      }

      // Footer RIG button
      const hmi_footer_button_rig = document.getElementById("hmi_footer_button_rig");
      hmi_addLongPress(hmi_footer_button_rig,
        () => { hmi_navigate_footer_popup("rig"); },
        () => {
          if (hmi_footer_selected == "rig") {
            switch (hmi_header_rig) {
              case "IC-7300":
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("A2");
                break;
              case "IC-9700":
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("94");
                break;
              default:
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("94");
                break;
            }
          }
          else {
            hmi_navigate_footer("rig");
          }
        }
      );
      /*
      // Rig FILTER button
      const btn = document.getElementById("rig_0_filter_main");
      hmi_addLongPress(btn,
        () => { hmi_open_popup('hmi_rig_panel_filter_main'); },
        () => { rig_incrementFilter(); }
      );
      */
    });





    async function loadJsonData(url) {
      try {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const jsonData = await response.json();
        return jsonData;
      } catch (error) {
        console_error("Error loading JSON:", error);
        return null;
      }
    }

    /*
    window.addEventListener("DOMContentLoaded", () => { // Populate Rig Selection Buttons
      objHmiRigsPage.updateRigDisplaySelectionButtons();
      for (let i = 0; i < objHmiRigsPage.arrDisplay.length; i++) {
        objHmiRigsPage.arrDisplay[i].updateElement("ALL");
      }
    });
    */

    /*
    window.addEventListener("DOMContentLoaded", () => { // Populate Rig Selection Buttons
      objHardwareControls.addEventListener("ArrowUp", () => {});
    });
    */

    setInterval(function() { /* Updates the header text based on refreshRate) */
      hmi_updateHeader();
    }, refreshRate);

    function hmi_updateHeader() { /* Updates the top header text (rig, antenna, etc...) */
      try {
        hmi_header_datetime = hmi_getDateTime(false);

        document.getElementById("hmi_header_rig").innerText = hmi_header_rig;
        document.getElementById("hmi_header_antenna").innerText = hmi_header_antenna;
        document.getElementById("hmi_header_rotator").innerText = hmi_header_rotator;
        document.getElementById("hmi_header_datetime").innerText = hmi_header_datetime;
      }
      catch(err) {
        console_log("Calling hmi_updateHeader();");
        console_log("Error:  " + err.message);
      }
    }

    function hmi_getDateTime(boolUTC = false) { /* Returns String of Date */
      d = new Date();
      strReturn = "error";
      const monthsFull = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];      
      const monthsAbrv = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];      
      
      strReturn = d.getDate();
      strReturn += "-";
      strReturn += monthsAbrv[d.getMonth()];
      strReturn += "-";
      strReturn += d.getFullYear();



      strHours = "00" + d.getHours();
      strMinutes = "00" + d.getMinutes();
      strSeconds = "00" + d.getSeconds();

      strReturn += " ";
      strReturn += strHours.slice(strHours.length - 2);
      strReturn += ":";
      strReturn += strMinutes.slice(strMinutes.length - 2);
      strReturn += ":";
      strReturn += strSeconds.slice(strSeconds.length - 2);


      return strReturn;
    }

    function hmi_navigate_footer(strSelectedButton) { /* Changes display page and highlights button */
      const buttons = ["hmi_footer_button_rig", "hmi_footer_button_antenna", "hmi_footer_button_tuner", "hmi_footer_button_rotator", "hmi_footer_button_satellites", "hmi_footer_button_scanner", "hmi_footer_button_settings"];

      const panels = ["hmi_body_panel_boot", "hmi_body_panel_rig", "hmi_body_panel_antenna", "hmi_body_panel_tuner", "hmi_body_panel_rotator", "hmi_body_panel_satellites", "hmi_body_panel_scanner", "hmi_body_panel_settings"]


      // Reset all buttons...
      for (let x in buttons) {
        objBtn = document.getElementById(buttons[x]);
        strClasses = objBtn.className;
        objBtn.className = strClasses.replace("w3-blue", "w3-dark-grey");
      }

      // Set selected button as highlighted...
      objBtn = document.getElementById("hmi_footer_button_" + strSelectedButton);
      strClasses = objBtn.className;
      objBtn.className = strClasses.replace("w3-dark-grey", "w3-blue");

      // Reset all panels...
      for (let x in panels) {
        objPanel = document.getElementById(panels[x]);
        objPanel.style.display = "none";
      }

      // Set active panel... 
      objPanel = document.getElementById("hmi_body_panel_" + strSelectedButton);
      objPanel.style.display = "block";
    }

    function hmi_navigate_footer_popup(strSelectedButton) {
      // Set active panel... 
      objPanel = document.getElementById("hmi_footer_panel_" + strSelectedButton);
      objPanel.style.display = "block";
      hmi_open_popup();
    }

    function hmi_close_footer_popup(strSelectedButton) {
      // Set active panel... 
      objPanel = document.getElementById("hmi_footer_panel_" + strSelectedButton);
      objPanel.style.display = "none";
      hmi_close_popup();
    }

    function hmi_open_popup(strPopupID, displaySlot) {
      // Set active panel... 
      objPopup = document.getElementById("hmi_popup_panel");
      objPopup.style.display = "block";
      if (strPopupID != undefined) {
        // Some panels have rig specific versions
        switch (strPopupID) {
          case "hmi_rig_panel_band":
          case "hmi_rig_panel_mode":
            let model = "";
            let slotIndex = -1;
            switch (displaySlot) {
              case DisplaySlot.A:
                slotIndex = objHmiRigsPage.displayA_arrDisplayIndex;
                break;
              case DisplaySlot.B:
                slotIndex = objHmiRigsPage.displayB_arrDisplayIndex;
                break;
            }
            model = objHmiRigsPage.arrDisplay[slotIndex].objRadio.radioType;


            strPopupID += "_" + model;
            break;

          case "hmi_rig_panel_repeater":
            objHmiRigsPage.arrDisplay[objHmiRigsPage.selectedDisplayIndex].saveRepeaterState();
            break;
        }
        // Display the panel
        objPanel = document.getElementById(strPopupID);
        objPanel.style.display = "block";
      }
    }

    function hmi_close_popup(strPopupID, radioType) {
      // Set active panel... 
      objPopup = document.getElementById("hmi_popup_panel");
      objPopup.style.display = "none";
      if (strPopupID != "") {
        // Some panels have rig specific versions
        switch (strPopupID) {
          case "hmi_rig_panel_band":
          case "hmi_rig_panel_mode":
            if (radioType != "") {
              strPopupID += "_" + radioType;
            }
            break;
        }
        // Hide the panel
        objPanel = document.getElementById(strPopupID);
        objPanel.style.display = "none";
      }
    }

    function hmi_close_all_popups() {
      // Set active panel... 
      objPopup = document.getElementById("hmi_popup_panel");
      objPopup.style.display = "none";

      let arrPopups = ["hmi_footer_panel_rig"
                      ,"hmi_rig_panel_mode"
                      ,"hmi_rig_panel_mode_IC-7300"
                      ,"hmi_rig_panel_mode_IC-9700"
                      ,"hmi_rig_panel_band"
                      ,"hmi_rig_panel_band_IC-7300"
                      ,"hmi_rig_panel_band_IC-9700"
                      ]
      arrPopups.forEach((popup)=>{document.getElementById(popup).style.display="none"})
    }

    function hmi_touch_start(strSelectedButton) {
      hmi_touch_start_button = strSelectedButton;
      const d = new Date();
      hmi_touch_start_time = d.getTime();
    }

    function hmi_touch_stop(strSelectedButton) {
      hmi_touch_stop_button = strSelectedButton;
      const d = new Date();
      hmi_touch_stop_time = d.getTime();

      // Long touch...
      if (hmi_touch_start_button == hmi_touch_stop_button) {
        if (hmi_touch_stop_time - hmi_touch_start_time > 500) {
          // LONG PRESS
          switch (strSelectedButton) {
            case "rig":
            case "antenna":
            case "tuner":
            case "rotator":
              hmi_navigate_footer_popup(strSelectedButton);
              break;
            case "rig_filter_main":
              hmi_open_popup('hmi_rig_panel_filter_main');
              break;
          }

        // Short touch...
        } else {
          // SHORT PRESS
          switch (strSelectedButton) {
            case "rig":
            case "antenna":
            case "tuner":
            case "rotator":
              if (hmi_footer_selected == strSelectedButton) {
                switch (strSelectedButton) {
                  case "rig":
                    switch (hmi_header_rig) {
                      case "IC-7300":
                        hmi_navigate_footer(strSelectedButton);
                        objHmiRigsPage.selectModel("A2");
                        break;
                      case "IC-9700":
                        hmi_navigate_footer(strSelectedButton);
                        objHmiRigsPage.selectModel("94");
                        break;
                      default:
                        hmi_navigate_footer(strSelectedButton);
                        objHmiRigsPage.selectModel("94");
                        break;
                    }
                    break;
                  case "antenna":
                  case "tuner":
                  case "rotator":
                    break;
                }
              } else {
                hmi_footer_selected = strSelectedButton;
                hmi_navigate_footer(strSelectedButton);
                objHmiRigsPage.selectModel("A2");
              }
              break;
            case "rig_filter_main":
              rig_incrementFilter();
              break;
          }
        }
      }
  
      hmi_touch_start_button = undefined;
      hmi_touch_stop_button = undefined;
      hmi_touch_start_time = undefined;
      hmi_touch_stop_time = undefined;
    }

    /*
    window.addEventListener('DOMContentLoaded', () => {

      // Utility: Attach pointer-based long press to a button.
      // shortPressFn is called if released before 750ms is up,
      // longPressFn is called if the user holds for 750ms.
      function hmi_addLongPress(button, longPressFn, shortPressFn) {
        let holdTimeout = null;
        let holdFired = false;
        button.addEventListener("pointerdown", () => {
          holdFired = false;
          holdTimeout = setTimeout(() => {
            holdFired = true;
            longPressFn();
          }, 750);
        });
        button.addEventListener("pointerup", () => {
          if (holdTimeout) {
            clearTimeout(holdTimeout);
            holdTimeout = null;
            if (!holdFired) {
              shortPressFn();
            }
          }
        });
      }

      // Footer RIG button
      const hmi_footer_button_rig = document.getElementById("hmi_footer_button_rig");
      hmi_addLongPress(hmi_footer_button_rig,
        () => { hmi_navigate_footer_popup("rig"); },
        () => {
          if (hmi_footer_selected == "rig") {
            switch (hmi_header_rig) {
              case "IC-7300":
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("A2");
                break;
              case "IC-9700":
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("94");
                break;
              default:
                hmi_navigate_footer("rig");
                objHmiRigsPage.selectModel("94");
                break;
            }
          }
          else {
            hmi_navigate_footer("rig");
          }
        }
      );
    });

    window.addEventListener('load', () => { // After Splash Screen has Displayed, Switch to RIG 
      if (hmi_footer_selected == "") {
        hmi_touch_start("rig");
        hmi_touch_stop("rig");
      }
    });
    */

  </script>
</head>
<body id="dasher_body" class="w3-black" onresize="/*global_dasherBodyResize();resizeDashboardTiles();*/">
  <!-- !PAGE CONTENT! -->
  <div class="w3-container" id="faceplate" style="margin: 0px; padding: 0px;">

    <div class="w3-container w3-cell" id="left_controls" style="display: none;">
    </div>

    <!-- Screen size is 1024 x 600 -->
    <div class="w3-container w3-cell hmi-display" id="screen" style="margin: 0px; padding: 0px;">

      <!-- Header Text -->
      <div class="w3-container w3-cell-top w3-cell-row hmi-display-header">
        <div class="w3-cell">Rig: <span id="hmi_header_rig">&lt;rig_name&gt;</span> </div>
        <div class="w3-cell">Antenna: <span id="hmi_header_antenna">&lt;ant_name&gt;</span> </div>
        <div class="w3-cell">Rotator: <span id="hmi_header_rotator">&lt;rot_az&gt;ºAZ, &lt;rot_el&gt;ºEL</span> </div>
        <div class="w3-cell"><span id="hmi_header_datetime">DD-MMM-YYYY HH:MM </span> </div>
      </div>

      <!-- Main -->
      <div class="w3-container hmi-display-body">
        <!-- Panel - Boot Screen -->
        <div id="hmi_body_panel_boot" class="w3-panel" style="display: block;">
          <br />
          <img src="assets/ShackMateLogo.jpg" style="padding-left: 250px; width: 700px;" />
          <!--<div class="" style="font-size: 60pt; padding-left: 40%;">DISPLAY</div>-->
          <div class="w3-monospace" style="font-size: 12pt; padding-left: 60%">
            Half Baked Circuits
            <span>[ver. 0.0]</span>
          </div>
        </div>

        <!-- Panel - Rig Screen -->
        <div id="hmi_body_panel_rig" class="w3-panel" style="display: none; margin: 0px; padding: 0px;">
          <input type="hidden" id="rig_addressBox" value="" style="display: none;">
          <!-- Command Box -->
          <div class="commandBox" style="display: none;">
            <label for="hexCommand">Enter command value (hex)</label>
            <input type="text" id="hexCommand" placeholder="FE FE 94 E0 03 FD" style="width:200px;">
            <button onclick="objSMDeviceRouter.sendCommand()">Send Command</button>
            <div class="sent-received">
              <div class="line">
                <span class="label">Sent Command:</span>
                <span class="value" id="sentCommand">--</span>
              </div>
              <div class="line">
                <span class="label">Received:</span>
                <span class="value" id="receivedCommand">--</span>
              </div>
            </div>
          </div>

          <svg width="990" height="525" viewbox="0 0 600 318.18181818" XXXviewBox="0 0 600 300"
               preserveAspectRatio="xMidYMid meet"
               xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="rig_blueGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#357ABD"/>
                <stop offset="100%" stop-color="#1F4E7B"/>
              </linearGradient>
              <linearGradient id="rig_grayGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#7D7968"/>
                <stop offset="100%" stop-color="#5E594F"/>
              </linearGradient>
              <linearGradient id="rig_orangeGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#FD7F2C"/>
                <stop offset="100%" stop-color="#FF6200"/>
              </linearGradient>
            </defs>
            <!-- Black Background -->
            <rect x="0" y="0" width="600" height="300" fill="black"/>

            <!-- Top Banner -->
            <g>
              <rect x="0" y="0" width="600" height="30" fill="#111"/>
              <circle id="rig_circle_status" cx="25" cy="8" r="4" fill="#fff"/>
              <text x="40" y="21" fill="#fff" font-family="sans-serif" font-size="16">icom</text>
              
              <!-- Gray Bar -->
              <rect x="0" y="30" width="600" height="10" fill="#555"/>
              <!-- Receiver ID in the center (yellow text) -->
              <text id="rig_receiverIDBanner" x="300" y="39"
                    fill="yellow" font-family="sans-serif" font-size="12"
                    text-anchor="middle">
              </text>
              <text id="rig_bannerDeviceCenter" x="300" y="21"
                    fill="#ccc" font-family="sans-serif" font-size="14"
                    text-anchor="middle">
              </text>
              <text id="rig_bannerDeviceRight" x="580" y="21"
                    fill="#fff" font-family="sans-serif" font-size="16"
                    text-anchor="end">
              </text>
            </g>

            <!-- POWER Button -->
            <g id="rig_powerButtonGroup" transform="translate(10,45)" style="cursor:pointer" 
              onclick="objHmiRigsPage.setPowerOn()">
              <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
              <rect id="rig_powerButtonIndicator" class="blinking-power-indicator-off" x="5" y="3" width="70" height="6" fill="#be0000"/>
              <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">POWER</text>
            </g>

            <!-- TRANSMIT Button -->
            <g id="rig_transmitButtonGroup" transform="translate(10,80)" style="display:none;cursor:pointer" onclick="objHmiRigsPage.transmit()">
              <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
              <rect id="rig_transmitButtonIndicator" x="5" y="3" width="70" height="6" fill="#555"/>
              <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">TRANSMIT</text>
            </g>

            <!-- Amp/Notch/NB/NR Group -->
            <g id="rig_ampNotchNBGroup" transform="translate(10,115)" style="display:none">
              <g>
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">P.AMP</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">NOTCH</text>
                </g>
              </g>
              <g transform="translate(0,25)">
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">NB</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">NR</text>
                </g>
              </g>
            </g>

            <!-- IC-7300 Tuner/Vox Group -->
            <g id="rig_ic7300TunerVoxGroup" transform="translate(10,165)" style="display:none">
              <g style="cursor:pointer">
                <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">TUNER</text>
              </g>
              <g style="cursor:pointer" transform="translate(0,35)">
                <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">VOX/BK‑IN</text>
              </g>
            </g>

            <!-- IC-9700 Call/Vox Group -->
            <g id="rig_ic9700CallVoxGroup" transform="translate(10,165)" style="display:none">
              <g style="cursor:pointer">
                <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">CALL DR</text>
              </g>
              <g style="cursor:pointer" transform="translate(0,35)">
                <rect width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">VOX/BK‑IN</text>
              </g>
            </g>

            <!-- Radio Selection Buttons (Bottom Left, Stacked Vertically) -->
            <g id="rig_modelSelectGroup" transform="translate(10,240)">
              <!-- Display A Selection Button -->
              <g style="cursor:pointer" id="rig_btnDisplayA" onclick="objHmiRigsPage.selectDisplay(DisplaySlot.A);/*objHmiRigsPage.selectModel(undefined, DisplaySlot.A)*/">
                <rect x="0" y="0" width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">No Rig</text>
              </g>
              <!-- Display B Selection Button -->
              <g style="cursor:pointer" id="rig_btnDisplayB" transform="translate(0,35)" onclick="objHmiRigsPage.selectDisplay(DisplaySlot.B);/*objHmiRigsPage.selectModel(undefined, DisplaySlot.B)*/">
                <rect x="0" y="0" width="80" height="30" fill="#333" rx="4" ry="4"/>
                <text x="40" y="20" fill="#fff" font-size="12" text-anchor="middle">No Rig</text>
              </g>
            </g>

            <!-- IC-7300 Buttons Group -->
            <g id="rig_ic7300ButtonsGroup" transform="translate(480,45)" style="display:none">
              <!-- Row 1: RIT, ΔTX, CLEAR -->
              <g>
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">RIT</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">ΔTX</text>
                </g>
                <g style="cursor:pointer" transform="translate(80,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">CLEAR</text>
                </g>
              </g>
              <!-- Row 2: SPLIT, A/B, V/M -->
              <g transform="translate(0,25)">
                <g style="cursor:pointer" onclick="objHmiRigsPage.splitButtonToggle()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <!-- Give the text an id so we can update its color -->
                  <text id="rig_splitBtnLabel" x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">SPLIT</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)" onclick="objHmiRigsPage.toggleVfoSide()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">A/B</text>
                </g>
                <g style="cursor:pointer" transform="translate(80,0)" onclick="objHmiRigsPage.operateModeToggle()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">V/M</text>
                </g>
              </g>
              <!-- Row 3: Up arrow, Down arrow, MPAD -->
              <g transform="translate(0,50)">
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="10" text-anchor="middle">▲</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)" onclick="hmi_open_popup('hmi_rig_panel_repeater');objHmiRigsPage.refreshRepeaterDetails();">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text id="toneBtnLabel" x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">TONE</text>
                </g>
                <!--
                <g style="cursor:pointer" transform="translate(40,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="10" text-anchor="middle">▼</text>
                </g>
                -->
                <g style="cursor:pointer" transform="translate(80,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">MPAD</text>
                </g>
              </g>
            </g>

            <!-- IC-9700 Buttons Group -->
            <g id="rig_ic9700ButtonsGroup" transform="translate(480,45)" style="display:none">
              <!-- Row 1: RIT, kHz/M‑CH, PBT -->
              <g>
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">RIT</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">kHz/M‑CH</text>
                </g>
                <g style="cursor:pointer" transform="translate(80,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">PBT</text>
                </g>
              </g>
              <!-- Row 2: SPLIT, A/B, V/M -->
              <g transform="translate(0,25)">
                <g style="cursor:pointer" onclick="objHmiRigsPage.splitButtonToggle()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text id="rig_splitBtnLabel" x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">SPLIT</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)"  onclick="objHmiRigsPage.toggleVfoSide()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">A/B</text>
                </g>
                <g style="cursor:pointer" transform="translate(80,0)" onclick="objHmiRigsPage.operateModeToggle()">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">V/M</text>
                </g>
              </g>
              <!-- Row 3: SCAN, TONE, MPAD -->
              <g transform="translate(0,50)">
                <g style="cursor:pointer">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">SCAN</text>
                </g>
                <g style="cursor:pointer" transform="translate(40,0)" onclick="hmi_open_popup('hmi_rig_panel_repeater');objHmiRigsPage.refreshRepeaterDetails();">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text id="toneBtnLabel" x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">TONE</text>
                </g>
                <g style="cursor:pointer" transform="translate(80,0)">
                  <rect width="35" height="20" fill="#333" rx="4" ry="4"/>
                  <text x="17" y="14" fill="#fff" font-size="8" text-anchor="middle">MPAD</text>
                </g>
              </g>
            </g>

            <!-- Side Bottom Row -->
            <g id="rig_bottomRowGroup" style="display:none" transform="translate(479,120)">
              <g style="cursor:pointer">
                <rect width="70" height="25" fill="#333" rx="3" ry="3"/>
                <text x="35" y="17" fill="#fff" font-size="12" text-anchor="middle">MENU</text>
              </g>
              <g style="cursor:pointer" transform="translate(0,28)">
                <rect width="70" height="25" fill="#333" rx="3" ry="3"/>
                <text x="35" y="17" fill="#fff" font-size="12" text-anchor="middle">FUNCTION</text>
              </g>
              <g id="rig_scopeButton" style="cursor:pointer" transform="translate(0,56)" onclick="objHmiRigsPage.toggleScope()">
                <rect width="70" height="25" fill="#333" rx="3" ry="3"/>
                <text x="35" y="17" fill="#fff" font-size="12" text-anchor="middle">M.SCOPE</text>
              </g>
              <g style="cursor:pointer" transform="translate(0,84)" onclick="rig_toggleSubBand()">
                <rect width="70" height="25" fill="#333" rx="3" ry="3"/>
                <text x="35" y="17" fill="#fff" font-size="12" text-anchor="middle">QUICK</text>
              </g>
              <g style="cursor:pointer" transform="translate(0,112)">
                <rect width="70" height="25" fill="#333" rx="3" ry="3"/>
                <text x="35" y="17" fill="#fff" font-size="12" text-anchor="middle">EXIT</text>
              </g>
            </g>


            <!-- Display A Band Group -->
            <g id="rig_display_slot_top" transform="translate(95,50)" onmouseup="objHmiRigsPage.dropHandler(event)"   onmouseover="objHmiRigsPage.dragoverHandler(event)">
              <g id="rig_0_Band" style="display:none;" transform="translate(0,0)" onclick="objHmiRigsPage.selectDisplay(DisplaySlot.A);" draggable="true" onmousedown="objHmiRigsPage.dragstartHandler(event)">
                <rect id="rig_0_selected" x="0" y="0" width="380" height="120" fill="lightblue" fill-opacity="0.00" stroke="blue" stroke-dasharray="12,3" stroke-linecap="round" stroke-opacity="0.00"  />
                <text id="rig_display_drag_down" x="20" y="115" fill="#f33" font-size="48" text-anchor="left" fill-opacity="0.00" >↓↓↓↓↓↓↓↓↓↓↓</text>
                <g style="cursor:pointer" onclick="/*objHmiRigsPage.selectDisplay(DisplaySlot.A); */hmi_open_popup('hmi_rig_panel_mode', DisplaySlot.A)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="url(#rig_blueGradient)"/>
                  <text id="rig_0_modeBtnLabel" x="25" y="15" fill="#fff" font-size="12" text-anchor="middle">LSB</text>
                </g>
                <g id="rig_0_filter_main" style="cursor:pointer" transform="translate(55,0)" onclick="objHmiRigsPage.incrementFilter(DisplaySlot.A)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="#222"/>
                  <rect x="0.5" y="0.5" width="50" height="20" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                  <text id="rig_0_filterBtnLabel" x="25" y="15" fill="#fff" font-size="12" text-anchor="middle">FIL1</text>
                </g>
                <g id="rig_0_agc_main" style="cursor:pointer" transform="translate(110,0)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="url(#rig_orangeGradient)"/>
                  <rect x="0.5" y="0.5" width="50" height="20" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                  <text id="rig_0_agcBtnLabel" x="25" y="15" fill="#fff" font-size="12" text-anchor="middle">AGC</text>
                </g>
                <g transform="translate(0,12)">
                  <text id="rig_0_mainFrequency" x="260" y="45" width="350" fill="#fff" font-size="38" text-anchor="end">
                    0000.000.000
                  </text>
                  <text id="rig_0_subFrequency" x="370" y="65" fill="#fff" font-size="16" text-anchor="end">
                    0000.000.000
                  </text>
                  <text id="rig_0_poValue" x="240" y="68" fill="#fff" font-size="14" text-anchor="left">
                    PO: 0.0
                  </text>
                  <text id="rig_0_swrValue" x="80" y="90" fill="#fff" font-size="12" text-anchor="left">
                    SWR: 0.0
                  </text>
                  <text id="rig_0_voltageValue" x="150" y="90" fill="#fff" font-size="12" text-anchor="left">
                    0.0 V
                  </text>
                  <text id="rig_0_amperageValue" x="210" y="90" fill="#fff" font-size="12" text-anchor="left">
                    0.0 A
                  </text>
                </g>

                <!-- Additional indicators inside Main_Band -->
                <g id="rig_0_bandIndicators" style="display:none" transform="translate(180,17)">
                  <text id="rig_0_bandIndicators_preamp" x="0" y="0" fill="#ccc" font-size="10">P.AMP</text>
                  <text id="rig_0_bandIndicators_tone" x="50" y="0" fill="#ccc" font-size="10">TONE</text>
                  <text id="rig_0_bandIndicators_duplex" x="100" y="0" fill="#ccc" font-size="10">SIMP</text>
                  <text id="rig_0_bandIndicators_agc" x="150" y="0" fill="#ccc" font-size="10">AGC‑M</text>
                </g>
                
                <!-- Operate Mode Indicator (Main_Band) -->
                <text id="rig_0_operateModeIndicator" x="300" y="50" fill="#fff" font-size="16" text-anchor="left">
                  VFO A
                </text>
                <!-- TX/RX Indicator -->
                <g id="rig_0_txIndicator" style="display:block" transform="translate(15,65)">
                  <rect id="rig_0_txRect" width="30" height="20" fill="none" stroke="#333333" stroke-width="2" rx="3" ry="3"/>
                  <text id="rig_0_txText" x="15" y="14" fill="#333333" font-size="12" font-weight="bold" text-anchor="middle">RX</text>
                </g>
                <!-- S/PO Meter-->
                <g id="rig_meterDisplayGroup" transform="translate(55,54) scale(0.5)">
                  <!-- S/PO Meter with dual scales (top S: and bottom PO:) -->
                  <g id="rig_0_spoMeterGroup" transform="translate(50,40)"></g>
                </g>
              </g>
            </g>

            <!-- Display B Band Group -->
            <g id="rig_display_slot_bottom" transform="translate(95,173)" onmouseup="objHmiRigsPage.dropHandler(event)"   onmouseover="objHmiRigsPage.dragoverHandler(event)">
              <g id="rig_1_Band" style="display:none" transform="translate(0,0)" onclick="objHmiRigsPage.selectDisplay(DisplaySlot.B);" draggable="true" onmousedown="objHmiRigsPage.dragstartHandler(event)">
                <rect id="rig_1_selected" x="0" y="0" width="380" height="120" fill="lightblue" fill-opacity="0.00" stroke="blue" stroke-dasharray="12,3" stroke-linecap="round" stroke-opacity="0.00"  />
                <text id="rig_display_drag_up" x="20" y="45" fill="#f33" font-size="48" text-anchor="left" fill-opacity="0.00">↑↑↑↑↑↑↑↑↑↑↑</text>
                <g style="cursor:pointer" onclick="hmi_open_popup('hmi_rig_panel_mode', DisplaySlot.B)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="url(#rig_blueGradient)"/>
                  <text id="rig_1_modeBtnLabel" x="25" y="15" fill="#fff" font-size="12" text-anchor="middle">LSB</text>
                </g>
                <g id="rig_1_filter_main" style="cursor:pointer" transform="translate(55,0)" onclick="objHmiRigsPage.incrementFilter(DisplaySlot.B)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="#222"/>
                  <rect x="0.5" y="0.5" width="50" height="20" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                  <text id="rig_1_filterBtnLabel" x="20" y="15" fill="#fff" font-size="12" text-anchor="middle">FIL1</text>
                </g>
                <g id="rig_1_agc_main" style="cursor:pointer" transform="translate(110,0)">
                  <rect x="0" y="0" width="50" height="20" rx="4" ry="4" fill="url(#rig_orangeGradient)"/>
                  <rect x="0.5" y="0.5" width="50" height="20" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                  <text id="rig_1_agcBtnLabel" x="25" y="15" fill="#fff" font-size="12" text-anchor="middle">AGC</text>
                </g>
                <g transform="translate(0,12)">
                  <text id="rig_1_mainFrequency" x="260" y="45" fill="#fff" font-size="38" text-anchor="end">
                    0000.000.000
                  </text>
                  <text id="rig_1_subFrequency" x="370" y="65" fill="#fff" font-size="16" text-anchor="end">
                    0000.000.000
                  </text>
                  <text id="rig_1_poValue" x="240" y="68" fill="#fff" font-size="14" text-anchor="left">
                    PO: 0.0
                  </text>
                  <text id="rig_1_swrValue" x="80" y="90" fill="#fff" font-size="12" text-anchor="left">
                    SWR: 0.0
                  </text>
                  <text id="rig_1_voltageValue" x="150" y="90" fill="#fff" font-size="12" text-anchor="left">
                    0.0 V
                  </text>
                  <text id="rig_1_amperageValue" x="210" y="90" fill="#fff" font-size="12" text-anchor="left">
                    0.0 A
                  </text>
                </g>
                <!-- Additional indicators inside Main_Band -->
                <g id="rig_1_bandIndicators" style="display:none" transform="translate(180,17)">
                  <text id="rig_1_bandIndicators_preamp" x="0" y="0" fill="#ccc" font-size="10">P.AMP</text>
                  <text id="rig_1_bandIndicators_tone" x="50" y="0" fill="#ccc" font-size="10">TONE</text>
                  <text id="rig_1_bandIndicators_duplex" x="100" y="0" fill="#ccc" font-size="10">SIMP</text>
                  <text id="rig_1_bandIndicators_agc" x="150" y="0" fill="#ccc" font-size="10">AGC‑M</text>
                </g>

                <!-- Operate Mode Indicator (Sub_Band) -->
                <text id="rig_1_operateModeIndicator" x="300" y="50" fill="#fff" font-size="16" text-anchor="left">
                  VFO A
                </text>
                <!-- TX/RX Indicator -->
                <g id="rig_1_txIndicator" style="display:block" transform="translate(15,65)">
                  <rect id="rig_1_txRect" width="30" height="20" fill="none" stroke="#333333" stroke-width="2" rx="3" ry="3"/>
                  <text id="rig_1_txText" x="15" y="14" fill="#333333" font-size="12" font-weight="bold" text-anchor="middle">RX</text>
                </g>
                <!-- S/PO Meter-->
                <g id="rig_meterDisplayGroup" transform="translate(55,54) scale(0.5)">
                  <!-- S/PO Meter with dual scales (top S: and bottom PO:) -->
                  <g id="rig_1_spoMeterGroup" transform="translate(50,40)"></g>
                </g>
              </g>
            </g>
            <g id="rig_scopePanel" style="display:block" transform="translate(95,50) scale(0.76)">
              <rect id="rig_scopePanel_background" width="500" height="158" fill="#333333" stroke="#333333" stroke-width="2" rx="3" ry="3"/>
              <rect id="rig_scopePanel_waterfall" transform="translate(10,10)" width="480" height="128" fill="#000" stroke="#099" stroke-width="1"></rect>
              <g id="rig_scopePanel_waterfall_data" transform="translate(12.5,12)" />
            </g>
          </svg>
        </div>

        <!-- Panel - Antenna Screen -->
        <div id="hmi_body_panel_antenna" class="w3-panel" style="display: none; margin: 0px; padding: 0px;">
          <!--
          <br /><br /><br /><br />
          <div class="w3-center" style="font-size: 60pt;">Antenna Controller</div>
          -->
          <svg width="990" height="525" viewBox="0 0 990 525" xmlns="http://www.w3.org/2000/svg" style="display: inline-block; vertical-align: top;">
            <!-- Outer border with pointer-events disabled so clicks pass through -->
            <rect x="0" y="0" width="990" height="525" fill="none" pointer-events="none" stroke="#888" stroke-width="1" />
            <!-- Top black bar -->
            <rect x="0" y="0" width="990" height="35" fill="black" />
            <!-- Banner Text -->
            <text x="50%" y="23" font-family="sans-serif" font-size="20" fill="#ccc" font-weight="bold" text-anchor="middle">
              ANTENNA SELECTION
            </text>
            <!-- Narrow gray bar -->
            <rect x="0" y="35" width="990" height="10" fill="#666" />
            
            <!-- OPERATING MODE Section with LEDS -->
            <g id="operating-mode" transform="translate(0,45)">
              <text x="495" y="40" font-family="sans-serif" font-size="23" font-weight="bold" fill="#fff" text-anchor="middle">
                OPERATING MODE
              </text>
              <!-- 14 LED indicators -->
              <text x="180" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">160m</text>
              <circle class="led off" data-index="0" cx="180" cy="100" r="8" />
              <text x="239" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">80m</text>
              <circle class="led off" data-index="1" cx="239" cy="100" r="8" />
              <text x="298" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">60m</text>
              <circle class="led off" data-index="2" cx="298" cy="100" r="8" />
              <text x="357" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">40m</text>
              <circle class="led off" data-index="3" cx="357" cy="100" r="8" />
              <text x="416" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">30m</text>
              <circle class="led off" data-index="4" cx="416" cy="100" r="8" />
              <text x="475" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">20m</text>
              <circle class="led off" data-index="5" cx="475" cy="100" r="8" />
              <text x="534" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">17m</text>
              <circle class="led off" data-index="6" cx="534" cy="100" r="8" />
              <text x="593" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">15m</text>
              <circle class="led off" data-index="7" cx="593" cy="100" r="8" />
              <text x="652" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">12m</text>
              <circle class="led off" data-index="8" cx="652" cy="100" r="8" />
              <text x="711" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">10m</text>
              <circle class="led off" data-index="9" cx="711" cy="100" r="8" />
              <text x="770" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">6m</text>
              <circle class="led off" data-index="10" cx="770" cy="100" r="8" />
              <text x="829" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">2m</text>
              <circle class="led off" data-index="11" cx="829" cy="100" r="8" />
              <text x="889" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">70cm</text>
              <circle class="led off" data-index="12" cx="889" cy="100" r="8" />
              <text x="950" y="70" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#fff">23cm</text>
              <circle class="led off" data-index="13" cx="950" cy="100" r="8" />
            </g>
            
            <!-- Left-side antenna button group -->
            <g id="button-group" transform="translate(10,55)">
              <g id="btnTransmit" class="function-button" data-index="-1" transform="translate(0,0)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  TRANSMIT
                </text>
              </g>
              <g id="btnTuner" class="function-button" data-index="-1" transform="translate(0,39)">
                <rect width="130" height="33.5" rx="5" />
                <text id="tunerText" x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  TUNER
                </text>
              </g>
              <g id="ant1" class="antenna-button" data-index="0" transform="translate(0,98)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  GROUND
                </text>
              </g>
              <g id="ant2" class="antenna-button" data-index="1" transform="translate(0,137)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  40m Dipole
                </text>
              </g>
              <g id="ant3" class="antenna-button" data-index="2" transform="translate(0,176)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  IMAX Vertical
                </text>
              </g>
              <g id="ant4" class="antenna-button" data-index="3" transform="translate(0,215)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  Hanging Loop
                </text>
              </g>
              <g id="ant5" class="antenna-button" data-index="4" transform="translate(0,254)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  80m Dipole
                </text>
              </g>
              <g id="ant6" class="antenna-button" data-index="5" transform="translate(0,293)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  G5RV
                </text>
              </g>
              <g id="ant7" class="antenna-button" data-index="6" transform="translate(0,332)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  6m Vertical
                </text>
              </g>
              <g id="ant8" class="antenna-button" data-index="7" transform="translate(0,371)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  BENT
                </text>
              </g>
              <g id="ant9" class="antenna-button" data-index="8" transform="translate(0,410)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  BUSTED
                </text>
              </g>
              <!--
              <g id="ant10" class="antenna-button" data-index="9" transform="translate(0,429)">
                <rect width="130" height="33.5" rx="5" />
                <text x="65" y="16.75" dominant-baseline="middle" font-family="sans-serif" font-size="15" font-weight="bold" text-anchor="middle">
                  STOLEN
                </text>
              </g>
              -->
            </g>
            
            <!-- TX/RX indicators + selected antenna name -->
            <g id="indicators" transform="translate(640,65)">
              <g id="txIndicator">
                <rect x="0" y="0" width="40" height="20" rx="5" fill="red" />
                <text id="txIndicatorText" x="20" y="14" font-family="sans-serif" font-size="12" fill="#fff" text-anchor="middle" font-weight="bold">
                  TX
                </text>
              </g>
              <g id="rxIndicator" transform="translate(45,0)">
                <rect x="0" y="0" width="40" height="20" rx="5" fill="green" />
                <text id="rxIndicatorText" x="20" y="14" font-family="sans-serif" font-size="12" fill="#fff" text-anchor="middle" font-weight="bold">
                  RX
                </text>
              </g>
              <text id="selectedAntennaName" x="100" y="15" font-family="sans-serif" font-size="18" fill="#fff">
                Port -: No Antenna Selected
              </text>
            </g>
          </svg>

          <!-- Option Buttons placed under the LED area inside the same container -->
          <div id="antenna-details">
            <h2>ANTENNA DETAILS</h2>
            <!-- Container for the option buttons -->
            <div class="buttons-container">
              <button id="antennaTypeButton">TYPE: None</button>
              <button id="antennaStyleButton">STYLE: None</button>
              <button id="antennaPolButton">POL: None</button>
              <button id="antennaMfgButton">MFG: None</button>
            </div>
            <!-- Dropdown containers for each option -->
            <div id="typeDropdown" class="dropdown-menu"></div>
            <div id="styleDropdown" class="dropdown-menu"></div>
            <div id="polDropdown" class="dropdown-menu"></div>
            <div id="mfgDropdown" class="dropdown-menu"></div>
          </div>
        </div>

        <!-- Panel - Tuner Screen -->
        <div id="hmi_body_panel_tuner" class="w3-panel" style="display: none;">
          <br /><br /><br /><br />
          <div class="w3-center" style="font-size: 60pt;">Tuner Controller</div>
        </div>

        <!-- Panel - Rotator Screen -->
        <div id="hmi_body_panel_rotator" class="w3-panel" style="display: none;">
          <svg id="mainSvg" width="990" height="525" viewBox="0 0 990 525" xmlns="http://www.w3.org/2000/svg">
            <!-- Full black background -->
            <rect x="0" y="0" width="990" height="525" fill="black" />

            <!-- Top bar -->
            <rect x="0" y="0" width="990" height="30" fill="#666" />
            
            <!-- Satellite Indicator (upper left of header) -->
            <g id="satelliteIndicator" transform="translate(10,2) scale(0.08)" fill="orange" stroke="white" stroke-width="5">
              <path d="M201.359,137.3l-43.831-43.831l11.453-11.452c1.407-1.407,2.197-3.314,2.197-5.304c0-1.989-0.79-3.896-2.197-5.304
              l-36.835-36.834c-2.929-2.928-7.677-2.928-10.606,0l-11.452,11.452L66.253,2.196c-2.93-2.928-7.678-2.928-10.606,0L18.813,39.03
              c-2.929,2.93-2.929,7.678,0,10.607l43.831,43.831l-11.453,11.452c-1.407,1.407-2.197,3.314-2.197,5.304s0.79,3.896,2.197,5.304
              l36.837,36.836c1.464,1.464,3.384,2.196,5.303,2.196c1.919,0,3.839-0.732,5.303-2.196l11.453-11.453l43.83,43.83
              c1.465,1.464,3.384,2.196,5.303,2.196c1.919,0,3.839-0.732,5.303-2.196l36.835-36.834c1.407-1.407,2.197-3.314,2.197-5.304
              C203.556,140.614,202.766,138.707,201.359,137.3z M34.723,44.334L60.95,18.107l38.53,38.526L82.314,73.799l-9.063,9.063
              L34.723,44.334z M93.331,136.454l-26.23-26.229l11.448-11.447c0.002-0.002,0.003-0.003,0.005-0.005l12.443-12.443l35.845-35.844
              l26.229,26.228l-11.446,11.446c-0.003,0.003-0.005,0.005-0.007,0.007l-18.417,18.418L93.331,136.454z M159.221,168.831
              l-38.527-38.526l26.229-26.229l38.527,38.527L159.221,168.831z"/>
              <path d="M72.344,188.555c-15.317,0.001-29.717-5.964-40.548-16.795C20.965,160.929,15,146.528,15,131.211
              c0-4.143-3.358-7.5-7.5-7.5c-4.143,0-7.5,3.358-7.5,7.5c0,19.324,7.526,37.491,21.189,51.155
              c13.663,13.664,31.829,21.189,51.152,21.189c0.001,0,0.002,0,0.004,0c4.142,0,7.499-3.358,7.499-7.5
              C79.845,191.912,76.486,188.555,72.344,188.555z"/>
              <path d="M69.346,174.133c4.142,0,7.5-3.357,7.5-7.5c0-4.143-3.358-7.5-7.5-7.5c-6.658,0-12.916-2.593-17.624-7.3
              c-4.707-4.707-7.299-10.965-7.299-17.622c0-4.142-3.357-7.5-7.5-7.5h0c-4.142,0-7.5,3.358-7.5,7.5
              c-0.001,10.663,4.152,20.688,11.693,28.229C48.656,169.981,58.682,174.133,69.346,174.133z"/>
            </g>

            <!-- Header Text (centered) -->
            <text x="50%" y="20" fill="#ccc" font-size="23" text-anchor="middle">
              ROTOR CONTROLLER
            </text>

            <!-- Toggle Button (Manual/Automatic) -->
            <g id="toggle-button" transform="translate(0,40)" style="cursor:pointer">
              <rect id="toggle-button-rect" width="130" height="37" rx="5" fill="blue" stroke="#999" stroke-width="1"/>
              <text id="mode-toggle" x="65" y="25" fill="white" font-size="14" text-anchor="middle">
                MANUAL
              </text>
            </g>

            <!-- Calibrate Button -->
            <g id="cal-button" transform="translate(0,85)" style="cursor:pointer">
              <rect width="130" height="37" rx="5" fill="orange" stroke="#999" stroke-width="1"/>
              <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">
                CALIBRATE
              </text>
            </g>

            <!-- Rotors Toggle Button -->
            <g id="rotors-toggle-button" transform="translate(0,130)" style="cursor:pointer">
              <rect id="rotors-toggle-rect" width="130" height="37" rx="5" fill="green" stroke="#999" stroke-width="1"/>
              <text id="rotors-toggle-text" x="65" y="25" fill="white" font-size="12" text-anchor="middle">
                ROTORS ENABLED
              </text>
            </g>

            <!-- M1–M6 Buttons -->
            <g id="m-buttons" transform="translate(0,200)">
              <g class="m-button" data-btn="M1" transform="translate(0,0)">
                <rect id="M1_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M1</text>
              </g>
              <g class="m-button" data-btn="M2" transform="translate(0,48)">
                <rect id="M2_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M2</text>
              </g>
              <g class="m-button" data-btn="M3" transform="translate(0,96)">
                <rect id="M3_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M3</text>
              </g>
              <g class="m-button" data-btn="M4" transform="translate(0,144)">
                <rect id="M4_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M4</text>
              </g>
              <g class="m-button" data-btn="M5" transform="translate(0,192)">
                <rect id="M5_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M5</text>
              </g>
              <g class="m-button" data-btn="M6" transform="translate(0,240)">
                <rect id="M6_rect" width="130" height="37" rx="5" fill="#555" stroke="#999" stroke-width="1"/>
                <text x="65" y="25" fill="white" font-size="14" text-anchor="middle">M6</text>
              </g>
            </g>

            <!-- ANALOG AZ METER -->
            <g id="analogAZGroup" transform="translate(160,75)">
              <rect x="0" y="0" width="300" height="170" rx="10" fill="black" stroke="white" stroke-width="2"/>
              <!-- AZ Scale -->
              <g transform="translate(0,-60) scale(0.50)">
                <path d="M 50,300 Q 300,100 550,300" fill="none" stroke="white" stroke-width="3"/>
                <g id="azTicks"></g>
                <g id="azLabels"></g>
                <g id="azPointer"></g>
              </g>
              <!-- AZ Meter Ellipse -->
              <g transform="translate(150,0)">
                <ellipse id="azMeterEllipse" cx="0" cy="0" rx="60" ry="18" fill="green"/>
                <text x="0" y="5" text-anchor="middle" font-size="16" fill="white" font-weight="bold">
                  AZIMUTH
                </text>
              </g>
              <!-- Blue target AZ display (lower right inside meter) -->
              <text id="targetAZDisplayAnalog" x="270" y="160" text-anchor="end" font-size="18" fill="blue" font-weight="bold"/>
            </g>

            <!-- DIGITAL AZ METER (hidden) -->
            <g id="digitalAZGroup" transform="translate(160,75)" style="display:none">
              <rect x="0" y="0" width="300" height="170" rx="10" fill="black" stroke="white" stroke-width="2"/>
              <g transform="translate(150,0)">
                <ellipse id="azMeterEllipseDigital" cx="0" cy="0" rx="60" ry="18" fill="green"/>
                <text x="0" y="5" text-anchor="middle" font-size="16" fill="white" font-weight="bold">
                  AZIMUTH
                </text>
              </g>
              <text id="rotorAZBigDigital" x="150" y="105" text-anchor="middle" font-family="Digital7, 'DS-Digital', monospace" font-size="48" fill="white">
                000
              </text>
              <text id="targetAZDisplayDigital" x="270" y="160" text-anchor="end" font-size="18" fill="blue" font-weight="bold"/>
            </g>

            <!-- AZ Buttons -->
            <g id="azButtons" transform="translate(490,135)">
              <g id="btnLeftCircle" style="cursor:pointer">
                <circle cx="0" cy="0" r="20" fill="blue"/>
                <path transform="translate(-14,-14) scale(1.3)" 
                      d="M11.036 0a11.034 11.034 0 1 0 7.578 19.053 
                         10.79 10.79 0 0 0 1.213-1.347l-3.188-2.418a6.668 6.668 0 0 1-.77.854 
                         7.036 7.036 0 1 1 2.124-6.109H16l3.9 4.908 4.1-4.908h-1.979
                         A11.046 11.046 0 0 0 11.036 0z" 
                      fill="white"/>
              </g>
              <g id="btnRightCircle" transform="translate(0,50)" style="cursor:pointer">
                <circle cx="0" cy="0" r="20" fill="blue"/>
                <path transform="translate(14,-14) scale(-1.3,1.3)" 
                      d="M11.036 0a11.034 11.034 0 1 0 7.578 19.053 
                         10.79 10.79 0 0 0 1.213-1.347l-3.188-2.418a6.668 6.668 0 0 1-.77.854 
                         7.036 7.036 0 1 1 2.124-6.109H16l3.9 4.908 4.1-4.908h-1.979
                         A11.046 11.046 0 0 0 11.036 0z" 
                      fill="white"/>
              </g>
            </g>

            <!-- ANALOG EL METER -->
            <g id="analogELGroup" transform="translate(160,285)">
              <rect x="0" y="0" width="300" height="170" rx="10" fill="black" stroke="white" stroke-width="2"/>
              <!-- EL Scale -->
              <g transform="translate(0,-60) scale(0.50)">
                <path d="M 50,300 Q 300,100 550,300" fill="none" stroke="white" stroke-width="3"/>
                <g id="elTicks"></g>
                <g id="elLabels"></g>
                <g id="elPointer"></g>
              </g>
              <!-- EL Meter Ellipse -->
              <g transform="translate(150,0)">
                <ellipse id="elMeterEllipse" cx="0" cy="0" rx="60" ry="18" fill="green"/>
                <text x="0" y="5" text-anchor="middle" font-size="16" fill="white" font-weight="bold">
                  ELEVATION
                </text>
              </g>
              <!-- Blue target EL display (lower right inside meter) -->
              <text id="targetELDisplayAnalog" x="270" y="160" text-anchor="end" font-size="18" fill="blue" font-weight="bold"/>
            </g>

            <!-- DIGITAL EL METER (hidden) -->
            <g id="digitalELGroup" transform="translate(160,285)" style="display:none">
              <rect x="0" y="0" width="300" height="170" rx="10" fill="black" stroke="white" stroke-width="2"/>
              <g transform="translate(150,0)">
                <ellipse id="elMeterEllipseDigital" cx="0" cy="0" rx="60" ry="18" fill="green"/>
                <text x="0" y="5" text-anchor="middle" font-size="16" fill="white" font-weight="bold">
                  ELEVATION
                </text>
              </g>
              <text id="rotorELBigDigital" x="150" y="105" text-anchor="middle" font-family="Digital7, 'DS-Digital', monospace" font-size="48" fill="white">
                000
              </text>
              <text id="targetELDisplayDigital" x="270" y="160" text-anchor="end" font-size="18" fill="blue" font-weight="bold"/>
            </g>

            <!-- EL Buttons -->
            <g id="elButtons" transform="translate(490,345)">
              <g id="btnUpArrow" style="cursor:pointer">
                <circle cx="0" cy="0" r="20" fill="blue"/>
                <path fill="white" d="M -12 6 L 12 6 L 0 -14 Z"/>
              </g>
              <g id="btnDownArrow" transform="translate(0,50)" style="cursor:pointer">
                <circle cx="0" cy="0" r="20" fill="blue"/>
                <path fill="white" d="M -12 -6 L 12 -6 L 0 14 Z"/>
              </g>
            </g>

            <!-- Oval Label above the Plot -->
            <g id="ovalLabel" transform="translate(540,40)">
              <ellipse cx="150" cy="25" rx="150" ry="25" fill="none" stroke="none"/>
              <text x="190" y="25" text-anchor="middle" dominant-baseline="middle" font-size="16">
                <tspan fill="red">ROTOR POSITION</tspan>
                <tspan>   </tspan>
                <tspan fill="blue">TARGET POSITION</tspan>
              </text>
            </g>

            <!-- Position Plot -->
            <g id="posPlot" transform="translate(550,100) scale(1.8)">
              <rect x="0" y="0" width="200" height="200" fill="transparent" pointer-events="all"/>
              <circle cx="100" cy="100" r="90" stroke="white" stroke-width="1" fill="none"/>
              <circle cx="100" cy="100" r="60" stroke="white" stroke-width="1" fill="none"/>
              <circle cx="100" cy="100" r="30" stroke="white" stroke-width="1" fill="none"/>
              <line x1="100" y1="10" x2="100" y2="190" stroke="white" stroke-width="1"/>
              <line x1="10" y1="100" x2="190" y2="100" stroke="white" stroke-width="1"/>
              <text x="100" y="5" fill="green" font-size="14" text-anchor="middle">N</text>
              <text x="180" y="25" fill="green" font-size="14" text-anchor="middle">NE</text>
              <text x="205" y="105" fill="green" font-size="14" text-anchor="middle">E</text>
              <text x="180" y="185" fill="green" font-size="14" text-anchor="middle">SE</text>
              <text x="100" y="210" fill="green" font-size="14" text-anchor="middle">S</text>
              <text x="20"  y="185" fill="green" font-size="14" text-anchor="middle">SW</text>
              <text x="-5"  y="105" fill="green" font-size="14" text-anchor="middle">W</text>
              <text x="20"  y="25"  fill="green" font-size="14" text-anchor="middle">NW</text>
              <!-- Target indicator (blue cross) -->
              <g id="targetIndicator" transform="translate(100,100)">
                <line x1="-10" y1="0" x2="10" y2="0" stroke="blue" stroke-width="2"/>
                <line x1="0" y1="-10" x2="0" y2="10" stroke="blue" stroke-width="2"/>
              </g>
              <!-- Rotor indicator (red ring) -->
              <circle id="rotorIndicator" cx="100" cy="100" r="12" fill="none" stroke="red" stroke-width="2"/>
            </g>

            <!-- Numeric Keypad -->
            <g id="keypadGroup" transform="translate(315,180)" style="display:none">
              <rect x="0" y="0" width="360" height="160" rx="10" fill="black" stroke="white" stroke-width="2"/>
              <text id="keypadPrompt" x="20" y="25" fill="white" font-size="16" text-anchor="start"></text>
              <text id="keypadDisplay" x="340" y="25" fill="white" font-size="20" text-anchor="end"></text>
              <g transform="translate(15,40)">
                <g class="keypad-btn" data-value="1" transform="translate(0,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">1</text>
                </g>
                <g class="keypad-btn" data-value="2" transform="translate(55,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">2</text>
                </g>
                <g class="keypad-btn" data-value="3" transform="translate(110,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">3</text>
                </g>
                <g class="keypad-btn" data-value="4" transform="translate(165,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">4</text>
                </g>
                <g class="keypad-btn" data-value="5" transform="translate(220,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">5</text>
                </g>
                <g class="keypad-btn" data-value="CLEAR" transform="translate(275,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="14" text-anchor="middle">CLEAR</text>
                </g>
              </g>
              <g transform="translate(15,100)">
                <g class="keypad-btn" data-value="6" transform="translate(0,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">6</text>
                </g>
                <g class="keypad-btn" data-value="7" transform="translate(55,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">7</text>
                </g>
                <g class="keypad-btn" data-value="8" transform="translate(110,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">8</text>
                </g>
                <g class="keypad-btn" data-value="9" transform="translate(165,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">9</text>
                </g>
                <g class="keypad-btn" data-value="0" transform="translate(220,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="20" text-anchor="middle">0</text>
                </g>
                <g class="keypad-btn" data-value="ENTER" transform="translate(275,0)">
                  <rect width="50" height="50" rx="5" fill="blue"/>
                  <text x="25" y="32" fill="white" font-size="14" text-anchor="middle">ENTER</text>
                </g>
              </g>
            </g>
          </svg>
        </div>

        <!-- Panel - Satellites Screen -->
        <div id="hmi_body_panel_satellites" class="w3-panel" style="display: none;">
          <br /><br /><br /><br />
          <div class="w3-center" style="font-size: 60pt;">Satellites</div>
        </div>

        <!-- Panel - Scanner Screen -->
        <div id="hmi_body_panel_scanner" class="w3-panel" style="display: none;">
          <br /><br /><br /><br />
          <div class="w3-center" style="font-size: 60pt;">Scanner</div>
        </div>

        <!-- Panel - Settings Screen -->
        <div id="hmi_body_panel_settings" class="w3-panel" style="display: none;">
          <br /><br /><br /><br />
          <div class="w3-center" style="font-size: 60pt;">Settings</div>
        </div>

      </div>
      <!-- Footer -->
      <div class="w3-container hmi-display-header w3-cell-row w3-cell-bottom">
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_rig"> RIG </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_antenna"
                  onclick="hmi_navigate_footer('antenna');"> Antenna </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_tuner"
                  onclick="hmi_navigate_footer('tuner');"> Tuner </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_rotator"
                  onclick="hmi_navigate_footer('rotator');"> Rotator </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_satellites"
                  onclick="hmi_navigate_footer('satellites');"> Satellites </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_scanner"
                  onclick="hmi_navigate_footer('scanner');"> Scanner </button>
        </div>
        <div class="w3-cell">
          <button class="w3-button w3-round w3-dark-grey w3-border w3-border-light-grey hmi-button" 
                  id="hmi_footer_button_settings"
                  onclick="hmi_navigate_footer('settings');"> Settings </button>
        </div>
      </div>

      <!--  All Popups  -->
      <div id="hmi_popup_panel" class="w3-modal">
      <div class="w3-modal-content w3-panel w3-dark-grey" style="width: 50%; height: 50%; position: absolute; top: 25%; left: 25%; padding: 0px;">
        <!--  Footer - Rig  -->
        <div class="w3-panel" id="hmi_footer_panel_rig" style="display: none; text-align: center;">
          <button class="w3-button w3-blue w3-margin" id="hmi_footer_panel_rig_7300" onclick="objHmiRigsPage.selectModel('94'); hmi_close_footer_popup('rig'); hmi_navigate_footer('rig');">IC-7300</button>
          <button class="w3-button w3-blue w3-margin" id="hmi_footer_panel_rig_9700" onclick="objHmiRigsPage.selectModel('A2'); hmi_close_footer_popup('rig'); hmi_navigate_footer('rig');">IC-9700</button>
        </div> 

        <!--  Rig - Mode  -->
        <div class="w3-panel" id="hmi_rig_panel_mode" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('LSB'); hmi_close_popup('hmi_rig_panel_mode');">LSB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('USB'); hmi_close_popup('hmi_rig_panel_mode');">USB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('AM'); hmi_close_popup('hmi_rig_panel_mode');">AM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW'); hmi_close_popup('hmi_rig_panel_mode');">CW</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY'); hmi_close_popup('hmi_rig_panel_mode');">RTTY</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('FM'); hmi_close_popup('hmi_rig_panel_mode');">FM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW-R'); hmi_close_popup('hmi_rig_panel_mode');">CW-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY-R'); hmi_close_popup('hmi_rig_panel_mode');">RTTY-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('DV'); hmi_close_popup('hmi_rig_panel_mode');">DV</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('DD'); hmi_close_popup('hmi_rig_panel_mode');">DD</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.toggleDataMode(); hmi_close_popup('hmi_rig_panel_mode');">DATA</button>
        </div> 
        <div class="w3-panel" id="hmi_rig_panel_mode_IC-7300" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('LSB'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">LSB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('USB'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">USB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('AM'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">AM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">CW</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">RTTY</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('FM'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">FM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW-R'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">CW-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY-R'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">RTTY-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.toggleDataMode(); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_7300);">DATA</button>
        </div> 
        <div class="w3-panel" id="hmi_rig_panel_mode_IC-9700" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('LSB'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">LSB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('USB'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">USB</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('AM'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">AM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">CW</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">RTTY</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('FM'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">FM</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('CW-R'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">CW-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('RTTY-R'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">RTTY-R</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('DV'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">DV</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.selectMode('DD'); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">DD</button>
          <button class="w3-button w3-blue w3-margin" style="width: 7em;" onclick="objHmiRigsPage.toggleDataMode(); hmi_close_popup('hmi_rig_panel_mode', Radio_Type.IC_9700);">DATA</button>
        </div> 

        <!--  Rig - Band  -->
        <div class="w3-panel" id="hmi_rig_panel_band" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('1.8'); hmi_close_popup('hmi_rig_panel_band');">1.8</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('3.5'); hmi_close_popup('hmi_rig_panel_band');">3.5</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('7'); hmi_close_popup('hmi_rig_panel_band');">7</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('10'); hmi_close_popup('hmi_rig_panel_band');">10</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('14'); hmi_close_popup('hmi_rig_panel_band');">14</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('18'); hmi_close_popup('hmi_rig_panel_band');">18</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('21'); hmi_close_popup('hmi_rig_panel_band');">21</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('24'); hmi_close_popup('hmi_rig_panel_band');">24</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('28'); hmi_close_popup('hmi_rig_panel_band');">28</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('50'); hmi_close_popup('hmi_rig_panel_band');">50</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('144'); hmi_close_popup('hmi_rig_panel_band');">144</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('430'); hmi_close_popup('hmi_rig_panel_band');">430</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('1240'); hmi_close_popup('hmi_rig_panel_band');">1240</button>
        </div> 
        <div class="w3-panel" id="hmi_rig_panel_band_IC-7300" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('1.8'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">1.8</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('3.5'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">3.5</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('7'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">7</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('10'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">10</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('14'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">14</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('18'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">18</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('21'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">21</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('24'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">24</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('28'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">28</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('50'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_7300);">50</button>
        </div> 
        <div class="w3-panel" id="hmi_rig_panel_band_IC-9700" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('144'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_9700);">144</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('430'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_9700);">430</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="objHmiRigsPage.selectBand('1240'); hmi_close_popup('hmi_rig_panel_band', Radio_Type.IC_9700);">1240</button>
        </div> 

        <!--  Rig - Filter [Main]  -->
        <div class="w3-panel" id="hmi_rig_panel_filter_main" style="display: none;">
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="rig_selectFilter('FIL1'); hmi_close_popup('hmi_rig_panel_filter_main');">FIL1</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="rig_selectFilter('FIL2'); hmi_close_popup('hmi_rig_panel_filter_main');">FIL2</button>
          <button class="w3-button w3-blue w3-margin" style="width: 5em;" onclick="rig_selectFilter('FIL3'); hmi_close_popup('hmi_rig_panel_filter_main');">FIL3</button>
        </div> 

        <!-- Rig - Tone -->
        <div class="w3-panel" id="hmi_rig_panel_repeater" style="display: block; margin: 0px; padding: 0px;">
          <svg width="600" height="300" x="-20" viewBox="0 0 600 300"
               preserveAspectRatio="xMidYMid meet"
               xmlns="http://www.w3.org/2000/svg">

            <!-- Black Background -->
            <rect x="0" y="0" width="600" height="300" fill="black" stroke="lightblue" stroke-width="4" onclick="objHmiRigsPage.clearFocus()" />

            <g transform="translate(0,0)">
            <text x="160" y="45" fill="#ccc" font-size="24">Tone & Repeater Selection</text>

              <!-- Tone Settings -->
              <g transform="translate(0,65)">
                <text x="170" y="40" fill="#ccc" font-size="20">Tone Settings</text>

                <!-- Tone Settings - TX Side -->
                <g transform="translate(25,60)">
                  <text x="60" y="5" fill="#ccc" font-size="16">Transmit</text>
                  <g transform="translate(0,12)" onclick="objHmiRigsPage.changeToneType('off', true)">
                    <rect id="hmi_rig_panel_repeater_tx_off_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_tx_off" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">OFF</text>
                  </g>
                  <g transform="translate(60,12)" onclick="objHmiRigsPage.changeToneType('tone', true)">
                    <rect id="hmi_rig_panel_repeater_tx_tone_button" x="0" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_tx_tone" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">TONE</text>
                  </g>
                  <g transform="translate(120,12)" onclick="objHmiRigsPage.changeToneType('dtcs', true)">
                    <rect id="hmi_rig_panel_repeater_tx_dtcs_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_tx_dtcs" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">DTCS</text>
                  </g>
                  <g id="rig_panel_repeater_tx_polarity_button" transform="translate(175,44)" onclick="objHmiRigsPage.changeDtcsPolarity(true)">
                    <rect x="0" y="0" width="30" height="34" rx="4" ry="4" fill="url(#rig_blueGradient)"/>
                    <rect x="0.5" y="0.5" width="30" height="34" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_tx_polarity_value" x="7.5" y="24" fill="#fff" font-size="22" text-anchor="left">N</text>
                  </g>
                  <g transform="translate(0,50)" onclick="objHmiRigsPage.changeToneValue(false, true)">
                    <circle r="20" cx="25" cy="12" fill="url(#rig_blueGradient)" />
                    <circle r="20" cx="25.5" cy="12.5" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1" />
                    <text id="rig_panel_repeater_tx_tone_down" x="25" y="20" fill="#fff" font-size="22" text-anchor="middle">—</text>
                  </g>
                  <g id="rig_panel_repeater_tx_tone_box" transform="translate(50,50)" onclick="objHmiRigsPage.giveFocus('rig_panel_repeater_tx_tone_value');">
                    <rect x="0" y="0" width="70" height="25" rx="4" ry="4" fill=""/>
                    <rect id="rig_repeater_tx_tone_value_highlight" x="0.5" y="0.5" width="70" height="25" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_tx_tone_value" x="35" y="20" fill="#fff" font-size="18" text-anchor="middle"> -- </text>
                  </g>
                  <g transform="translate(120,50)" onclick="objHmiRigsPage.changeToneValue(true, true)">
                    <circle r="20" cx="25" cy="12" fill="url(#rig_blueGradient)" />
                    <circle r="20" cx="25.5" cy="12.5" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1" />
                    <text id="rig_panel_repeater_tx_tone_up" x="25" y="20" fill="#fff" font-size="24" text-anchor="middle">+</text>
                  </g>                  
                </g>

                <!-- Tone Settings - RX Side -->
                <g transform="translate(250,60)">
                  <text x="60" y="5" fill="#ccc" font-size="16">Receive</text>
                  <g transform="translate(0,12)" onclick="objHmiRigsPage.changeToneType('off', false)">
                    <rect id="hmi_rig_panel_repeater_rx_off_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_rx_off" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">OFF</text>
                  </g>
                  <g transform="translate(60,12)" onclick="objHmiRigsPage.changeToneType('tone', false)">
                    <rect id="hmi_rig_panel_repeater_rx_tone_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_rx_tone" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">T-SQL</text>
                  </g>
                  <g transform="translate(120,12)" onclick="objHmiRigsPage.changeToneType('dtcs', false)">
                    <rect id="hmi_rig_panel_repeater_rx_dtcs_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="hmi_rig_panel_repeater_rx_dtcs" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">DTCS</text>
                  </g>
                  <g id="rig_panel_repeater_rx_polarity_button" transform="translate(175,44)" onclick="objHmiRigsPage.changeDtcsPolarity(false)">
                    <rect x="0" y="0" width="30" height="34" rx="4" ry="4" fill="url(#rig_blueGradient)"/>
                    <rect x="0.5" y="0.5" width="30" height="34" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_rx_polarity_value" x="7.5" y="24" fill="#fff" font-size="22" text-anchor="left">N</text>
                  </g>
                  <g transform="translate(0,50)" onclick="objHmiRigsPage.changeToneValue(false, false)">
                    <circle r="20" cx="25" cy="12" fill="url(#rig_blueGradient)" />
                    <circle r="20" cx="25.5" cy="12.5" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1" />
                    <text id="rig_panel_repeater_rx_tone_down" x="25" y="20" fill="#fff" font-size="22" text-anchor="middle">—</text>
                  </g>
                  <g id="rig_panel_repeater_rx_tone_box" transform="translate(50,50)" onclick="objHmiRigsPage.giveFocus('rig_panel_repeater_rx_tone_value');">
                    <rect x="0" y="0" width="70" height="25" rx="4" ry="4" fill=""/>
                    <rect id="rig_panel_repeater_rx_tone_value_highlight" x="0.5" y="0.5" width="70" height="25" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_rx_tone_value" x="35" y="20" fill="#fff" font-size="18" text-anchor="middle"> -- </text>
                  </g>
                  <g transform="translate(120,50)" onclick="objHmiRigsPage.changeToneValue(true, false)">
                    <circle r="20" cx="25" cy="12" fill="url(#rig_blueGradient)" />
                    <circle r="20" cx="25.5" cy="12.5" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1" />
                    <text id="rig_panel_repeater_rx_tone_up" x="25" y="20" fill="#fff" font-size="24" text-anchor="middle">+</text>
                  </g>                  
                </g>

              <!-- Duplex Options -->
              </g>
              <g transform="translate(480,105)">
                <text x="0" y="0" fill="#ccc" font-size="20">Offset</text>
                  <g transform="translate(0,20)" onclick="objHmiRigsPage.changeDuplex(false, false)">
                    <rect id="rig_panel_repeater_simplex_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_simplex" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">SIMP</text>
                  </g>
                  <g transform="translate(0,50)" onclick="objHmiRigsPage.changeDuplex(true, false)">
                    <rect id="rig_panel_repeater_duplex_down_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_duplex_down" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">DUP-</text>
                  </g>
                  <g transform="translate(0,80)" onclick="objHmiRigsPage.changeDuplex(true, true)">
                    <rect id="rig_panel_repeater_duplex_up_button" x="0" y="0" width="50" height="22" rx="4" ry="4" fill=""/>
                    <rect x="0.5" y="0.5" width="50" height="22" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                    <text id="rig_panel_repeater_duplex_up" x="25" y="16" fill="#fff" font-size="14" text-anchor="middle">DUP+</text>
                  </g>
              </g>
            </g>

            <!-- OK / Cancel Buttons -->
            <g transform="translate(360,250)">
              <g transform="translate(0,0)" onclick="objHmiRigsPage.arrDisplay[objHmiRigsPage.selectedDisplayIndex].restoreRepeaterState(); hmi_close_popup('hmi_rig_panel_repeater');">
                <rect x="0" y="0" width="100" height="32" rx="4" ry="4" fill="url(#rig_grayGradient)"/>
                <rect x="0.5" y="0.5" width="100" height="32" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                <text id="rig_panel_repeater_cancel" x="50" y="23" fill="#fff" font-size="22" text-anchor="middle">Cancel</text>
              </g>
              <g transform="translate(120,0)" onclick="hmi_close_popup('hmi_rig_panel_repeater');">
                <rect x="0" y="0" width="100" height="32" rx="4" ry="4" fill="url(#rig_blueGradient)"/>
                <rect x="0.5" y="0.5" width="100" height="32" rx="3.5" ry="3.5" fill="none" stroke="#444" stroke-width="1"/>
                <text id="rig_panel_repeater_ok" x="50" y="23" fill="#fff" font-size="22" text-anchor="middle">OK</text>
              </g>
            </g>
          </svg>

        </div>

      </div>

    </div>

    <div class="w3-container w3-cell" id="right_controls" style="display: none;">
      <canvas id="canvas" width="400" height="400" style="background-color:#000"></canvas>
      <script> /* Canvas scripts */
        const canvas = document.getElementById("canvas");
        const ctx = canvas.getContext("2d");
        let radius = canvas.height / 2;
        ctx.translate(radius, radius);
        radius = radius * 0.90
        drawClock();

        function drawClock() {
          drawFace(ctx, radius);
        }

        function drawFace(ctx, radius) {
          const grad = ctx.createRadialGradient(0, 0 ,radius * 0.95, 0, 0, radius * 1.05);
          grad.addColorStop(0, '#333');
          grad.addColorStop(0.5, 'white');
          grad.addColorStop(1, '#333');

          ctx.beginPath();
          ctx.arc(0, 0, radius, 0, 2 * Math.PI);
          ctx.fillStyle = 'darkgray';
          ctx.fill();

          ctx.strokeStyle = grad;
          ctx.lineWidth = radius*0.1;
          ctx.stroke();

          ctx.beginPath();
          ctx.arc(0, 0, radius * 0.1, 0, 2 * Math.PI);
          ctx.fillStyle = '#333';
          ctx.fill();
        }
      </script>
    </div>

    <script type="text/javascript">
      // Get the modal
      var modal = document.getElementById('hmi_popup_panel');

      // When the user clicks anywhere outside of the modal, close it
      window.onclick = function(event) {
        if (event.target == modal) {
            modal.style.display = "none";
            hmi_close_all_popups();
          }
      };


      /*
      //disable right click
      window.addEventListener("contextmenu", function(e) { e.preventDefault(); })
      //disable multi touch touch stuff
      window.addEventListener("touchstart", touchHandler, { passive: false, capture: false, once: false });
      function touchHandler(event) {
        if (event.touches.length > 1) {
          //the event is multi-touch
          event.preventDefault();
          event.stopImmediatePropagation();
          return false;
        }
      };
      */
    </script>

  </div>


</body>
</html>

