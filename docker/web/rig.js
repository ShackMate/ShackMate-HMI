const DisplaySlot = {
  A:    "0", 
  B:    "1", 
  None: "" 
}

class hmiRigsPage {
  arrDisplay = [];
  displayA_radioAddress = "";
  displayB_radioAddress = "";
  displayA_arrDisplayIndex = -1;
  displayB_arrDisplayIndex = -1;
  selectedDisplayIndex = -1; // ????
  activeDisplaySlot = DisplaySlot.None;
  focusElement;

  // Used for swapping the top and bottom displays in dual display mode...
  displaySlotDraggableId = "";
  displayTopId = "rig_0_Band";
  displayBottomId = "rig_1_Band";
  boolDragging = false;

  constructor(objArrRadio) {
    for (let i = 0; i < objArrRadio.length; i++) {
      let objHmiRig = new hmiRig(objArrRadio[i]);
      this.addDisplay(objHmiRig);
    }

    /* DO I NEED THIS CODE???  PRETTY SURE I DON'T (01-AUG-2025)
    if (this.arrDisplay.length > 0) {
      window.addEventListener('onload', () => {
        this.selectedDisplayIndex = 0;
        this.selectDisplay(DisplaySlot.A);
      });
    }
    */
  }

  addDisplay(objHmiRig) {
    this.arrDisplay.push(objHmiRig);

    if (this.displayA_arrDisplayIndex < 0) {
      this.displayA_arrDisplayIndex = this.arrDisplay.length - 1;
      this.displayA_radioAddress = objHmiRig.objRadio.address;
      objHmiRig.boolDisplay = true;
      objHmiRig.displayIndex = this.displayA_arrDisplayIndex;
      objHmiRig.displaySlot = DisplaySlot.A;
    }
    else if (this.displayB_arrDisplayIndex < 0) {
      this.displayB_arrDisplayIndex = this.arrDisplay.length - 1;
      this.displayB_radioAddress = objHmiRig.objRadio.address;
      objHmiRig.boolDisplay = true;
      objHmiRig.displayIndex = this.displayB_arrDisplayIndex;
      objHmiRig.displaySlot = DisplaySlot.B;
    }

    if (this.activeDisplaySlot == DisplaySlot.None) {
      this.activeDisplaySlot = DisplaySlot.A;
      this.selectedDisplayIndex = this.arrDisplay.length - 1;
    }

    this.informDisplayThatItIsActive();
  }

  informDisplayThatItIsActive() {
    for (let i = 0; i < this.arrDisplay.length; i++) {
      if (i == this.selectedDisplayIndex) {
        this.arrDisplay[i].boolActiveDisplay = true;
      }
      else {
        this.arrDisplay[i].boolActiveDisplay = false;
      }
    }
  }

  dragstartHandler(ev) {
    // rig_0_Band || rig_1_Band
    this.displaySlotDraggableId = ev.currentTarget.id;
    this.boolDragging = true;
  }

  dragoverHandler(ev) {
    ev.preventDefault();
    if (this.boolDragging) {
      const btnDragDown = document.getElementById("rig_display_drag_down");
      const btnDragUp = document.getElementById("rig_display_drag_up");
      const highlightDisplayA = document.getElementById(`rig_0_selected`);
      const highlightDisplayB = document.getElementById(`rig_1_selected`);

      if (this.displaySlotDraggableId == "rig_0_Band") {
        btnDragDown.setAttribute("fill-opacity", "1.00");
        highlightDisplayA.setAttribute("fill-opacity", "0.30");

        if (ev.currentTarget.id == "rig_display_slot_bottom") {
          highlightDisplayB.setAttribute("fill-opacity", "0.30");
        }
        else {
          highlightDisplayB.setAttribute("fill-opacity", "0.00");
        }
      }
      else if (this.displaySlotDraggableId == "rig_1_Band") {
        btnDragUp.setAttribute("fill-opacity", "1.00");
        highlightDisplayB.setAttribute("fill-opacity", "0.30");

        if (ev.currentTarget.id == "rig_display_slot_top") {
          highlightDisplayA.setAttribute("fill-opacity", "0.30");
        }
        else {
          highlightDisplayA.setAttribute("fill-opacity", "0.00");
        }
      }

    }
  }

  dropHandler(ev) {
    let boolSwap = false;
    const btnDragDown = document.getElementById("rig_display_drag_down");
    const btnDragUp = document.getElementById("rig_display_drag_up");
    const highlightDisplayA = document.getElementById(`rig_0_selected`);
    const highlightDisplayB = document.getElementById(`rig_1_selected`);

    ev.preventDefault();

    btnDragDown.setAttribute("fill-opacity", "0.00");
    btnDragUp.setAttribute("fill-opacity", "0.00");
    highlightDisplayA.setAttribute("fill-opacity", "0.00");
    highlightDisplayB.setAttribute("fill-opacity", "0.00");


    if (this.boolDragging) {
      switch(ev.currentTarget.id) {
        case "rig_display_slot_bottom":
          if (this.displayBottomId != this.displaySlotDraggableId) {
            boolSwap = true;
          }
          break;

        case "rig_display_slot_top":
          if (this.displayTopId != this.displaySlotDraggableId) {
            boolSwap = true;
          }
          break;

        default:
          this.displaySlotDraggableId = "";
          this.boolDragging = false;
          break;
      }
    }

    if (boolSwap) {
      this.swapDisplayPositions();
      this.displaySlotDraggableId = "";
    }

    this.boolDragging = false;
  }

  manualSwap() {
      this.swapDisplayPositions();
      this.displaySlotDraggableId = "";
      this.boolDragging = false;
      document.getElementById("rig_swap_displays").style.display = "none";
  }

  swapDisplayPositions() {
    const oldIndexA = this.displayA_arrDisplayIndex; 
    const oldIndexB = this.displayB_arrDisplayIndex; 
    const oldAddressA = this.displayA_radioAddress; 
    const oldAddressB = this.displayB_radioAddress; 

    this.displayA_arrDisplayIndex = oldIndexB;
    this.displayB_arrDisplayIndex = oldIndexA;
    this.displayA_radioAddress = oldAddressB; 
    this.displayB_radioAddress = oldAddressA; 

    this.arrDisplay[this.displayA_arrDisplayIndex].displayIndex = this.displayA_arrDisplayIndex;
    this.arrDisplay[this.displayB_arrDisplayIndex].displayIndex = this.displayB_arrDisplayIndex;

    this.arrDisplay[this.displayA_arrDisplayIndex].displaySlot = this.displaySlot = DisplaySlot.A;
    this.arrDisplay[this.displayB_arrDisplayIndex].displaySlot = this.displaySlot = DisplaySlot.B;

    this.updateRigDisplaySelectionButtons();

    this.arrDisplay[this.displayA_arrDisplayIndex].updateElement("ALL", DisplaySlot.A);
    this.arrDisplay[this.displayB_arrDisplayIndex].updateElement("ALL", DisplaySlot.B);

    this.updateBasedOnSelectedModel();
  }

  updateRigDisplaySelectionButtons() {
    const btnDisplayAText = document.querySelector("#rig_btnDisplayA text");
    const btnDisplayBText = document.querySelector("#rig_btnDisplayB text");

    if (this.displayA_arrDisplayIndex >= 0) {
      btnDisplayAText.innerHTML = this.arrDisplay[this.displayA_arrDisplayIndex].objRadio.radioType;
    }
    if (this.displayB_arrDisplayIndex >= 0) {
      btnDisplayBText.innerHTML = this.arrDisplay[this.displayB_arrDisplayIndex].objRadio.radioType;
    }
  }

  selectModel(radioAddress, display) {
    /*
      Expects:  radioAddress - of radio to select
             OR displaySlot - to select

             IF BOTH, assign radio to the display if not already assigned...
    */
    let displayIndex = this.selectedDisplayIndex; // this.arrDisplay[x] index for specified radioAddress 
    let boolCurrentlyDisplayed = false;           // Is the radioAddress specified currently being displayed?
    let currentDisplay = "";                      // A, B, etc...
    let targetDisplay = "";                       // A, B, etc...

    // Determine the arrDisplay[x] index based on radioAddress...
    for (let i = 0; i < this.arrDisplay.length; i++) {
      if (this.arrDisplay[i].objRadio.address == radioAddress) {
        displayIndex = i;
        break;
      }
    }

    // If there is no arrDisplay record for the requested radioAddress, report error...
    if (displayIndex == -1 && radioAddress != undefined) {
      console_error(`hmiRigsPage.selectModel(${radioAddress}) failed:  There is no display with that address.`);
    }
    // Otherwise, determine targetDisplay and assign radio if needed, then set as active display...
    else {

      // Assign radioAddress if not passed into function at this point...
      if (radioAddress == undefined) {
        radioAddress = this.arrDisplay[displayIndex].objRadio.address;
      }

      // Is it currently displayed?
      if (this.displayA_arrDisplayIndex == displayIndex) {
        boolCurrentlyDisplayed = true;
        currentDisplay = DisplaySlot.A;
      }
      else if (this.displayB_arrDisplayIndex == displayIndex) {
        boolCurrentlyDisplayed = true;
        currentDisplay = DisplaySlot.B;
      }

      // Is there a target display?  If not, use current display or "A" (if not currently displayed)...
      if (!display) {
        if (boolCurrentlyDisplayed) {
          targetDisplay = currentDisplay;
        }
        else {
          targetDisplay = DisplaySlot.A;
        }
      }
      else {
        targetDisplay = display;
      }

      // Set the display to use the specified radio...
      switch(targetDisplay) {
        case DisplaySlot.A:
          this.displayA_radioAddress = radioAddress;
          this.displayA_arrDisplayIndex = displayIndex;
          this.arrDisplay[this.displayA_arrDisplayIndex]
          break;

        case DisplaySlot.B:
          this.displayB_radioAddress = radioAddress;
          this.displayB_arrDisplayIndex = displayIndex;
          break;

        default:
          console_error(`hmiRigsPage.selectModel(${radioAddress}) failed:  targetDisplay = ${targetDisplay}, not recognized.`);
      }

      // Select this target display...
      this.selectedDisplayIndex = displayIndex;
      for (let i = 0; i < this.arrDisplay.length; i++) {
        this.arrDisplay[i].objRadio.active = false;
      }
      this.arrDisplay[this.selectedDisplayIndex].objRadio.active = true;

      // Notify hmiRig object...
      this.arrDisplay[this.selectedDisplayIndex].boolDisplay = true;

      // Update all elements for this display...
      this.highlightSelectedRig(radioAddress);
      this.updateBasedOnSelectedModel();
      this.arrDisplay[this.selectedDisplayIndex].updateElement("ALL");

      this.informDisplayThatItIsActive();
    }
  }

  // Highlight selected rig button
  highlightSelectedRig(radioAddress) {
    let activeDisplay = "";
    const btnDisplayARect = document.querySelector("#rig_btnDisplayA rect");
    const btnDisplayAText = document.querySelector("#rig_btnDisplayA text");
    const btnDisplayBRect = document.querySelector("#rig_btnDisplayB rect");
    const btnDisplayBText = document.querySelector("#rig_btnDisplayB text");
    const highlightDisplayA = document.getElementById(`rig_${DisplaySlot.A}_selected`);
    const highlightDisplayB = document.getElementById(`rig_${DisplaySlot.B}_selected`);


    if (this.displayA_radioAddress == radioAddress) {
      activeDisplay = DisplaySlot.A;
    }
    else if (this.displayB_radioAddress == radioAddress) {
      activeDisplay = DisplaySlot.B;
    }
    else {
      console_error(`hmiRigsPage.highlightSelectedRig(${radioAddress}) failed: address not currently displayed`);
    }

    if (activeDisplay != "") {
      // Reset both to dark
      btnDisplayARect.setAttribute("fill", "#333");
      btnDisplayAText.setAttribute("fill", "#fff");
      btnDisplayBRect.setAttribute("fill", "#333");
      btnDisplayBText.setAttribute("fill", "#fff");
      //highlightDisplayA.style.display = "none";
      //highlightDisplayB.style.display = "none";
      highlightDisplayA.setAttribute("fill-opacity", "0.00");
      highlightDisplayA.setAttribute("stroke-opacity", "0.00");
      highlightDisplayB.setAttribute("fill-opacity", "0.00");
      highlightDisplayB.setAttribute("stroke-opacity", "0.00");




      if (this.displayA_arrDisplayIndex >= 0) {
        btnDisplayAText.setAttribute("text", this.arrDisplay[this.displayA_arrDisplayIndex].objRadio.radioType);

        if (activeDisplay == DisplaySlot.A) {
          btnDisplayARect.setAttribute("fill", "#ccff66");
          btnDisplayAText.setAttribute("fill", "#000");
          //highlightDisplayA.style.display = "block";
          highlightDisplayA.setAttribute("fill-opacity", "0.12");
          highlightDisplayA.setAttribute("stroke-opacity", "1.00");
        }
      }

      if (this.displayB_arrDisplayIndex >= 0) {
        btnDisplayBText.setAttribute("text", this.arrDisplay[this.displayB_arrDisplayIndex].objRadio.radioType);

        if (activeDisplay == DisplaySlot.B) {
          btnDisplayBRect.setAttribute("fill", "#ccff66");
          btnDisplayBText.setAttribute("fill", "#000");
          //highlightDisplayB.style.display = "block";
          highlightDisplayB.setAttribute("fill-opacity", "0.12");
          highlightDisplayB.setAttribute("stroke-opacity", "1.00");
        }
      }
    }
  }

  // Update buttons, disabling buttons that don't work for selected model
  updateBasedOnSelectedModel() {
    let activeRadio = this.arrDisplay[this.selectedDisplayIndex].objRadio;
    let activeModel = activeRadio.radioType;
    let activeAddress = activeRadio.address;




    console_log("hmiRigsPage.updateBasedOnSelectedModel()");

    // Update HMI Header..
    hmi_header_rig = activeModel;





    // Hide tuner/call and button groups initially
    document.getElementById("rig_ic7300TunerVoxGroup").style.display = "none";
    document.getElementById("rig_ic9700CallVoxGroup").style.display = "none";
    document.getElementById("rig_ic7300ButtonsGroup").style.display = "none";
    document.getElementById("rig_ic9700ButtonsGroup").style.display = "none";





    // BUTTON ELEMENTS...

    // Show common UI elements
    switch (activeModel) {
      case Radio_Type.Generic_Icom:
      case Radio_Type.IC_7300:
      case Radio_Type.IC_9700:
        document.getElementById("rig_transmitButtonGroup").style.display = "block";
        document.getElementById("rig_ampNotchNBGroup").style.display = "block";
        document.getElementById("rig_bottomRowGroup").style.display = "block";

        break;

      default:
        //nothing...
    }

    // Show radio specific UI elements
    switch (activeModel) {
      case Radio_Type.IC_7300:
        document.getElementById("rig_ic7300ButtonsGroup").style.display = "block";
        document.getElementById("rig_ic7300TunerVoxGroup").style.display = "block";
        document.getElementById("rig_bannerDeviceRight").textContent = "IC‑7300";
        document.getElementById("rig_bannerDeviceCenter").textContent = "HF/50MHz TRANSCEIVER";

        setTimeout(() => {activeRadio.sendFrequencyQuery();}, 150);
        setTimeout(() => {activeRadio.sendDefaultMode();}, 350);
        setTimeout(() => {activeRadio.send0FCommand();}, 600);

        break;

      case Radio_Type.IC_9700:
        document.getElementById("rig_ic9700ButtonsGroup").style.display = "block";
        document.getElementById("rig_ic9700CallVoxGroup").style.display = "block";
        document.getElementById("rig_bannerDeviceRight").textContent = "IC‑9700";
        document.getElementById("rig_bannerDeviceCenter").textContent = "VHF/UHF ALL MODE TRANSCEIVER";

        activeRadio.sendReceiverIDCommand();
        setTimeout(() => {activeRadio.sendFrequencyQuery();}, 150);
        setTimeout(() => {activeRadio.sendDefaultMode();}, 350);
        setTimeout(() => {activeRadio.send0FCommand();}, 600);

        break;

      default:
        //nothing...
    }





    // BAND ELEMENTS...

    //document.getElementById("rig_1_Band").style.display = "none";

    // Default operate mode => VFO side A
    // rig_operateMode = "VFO";
    // rig_vfoToggle = false;
    document.getElementById("rig_0_Band").style.display = "block";
    document.getElementById("rig_1_Band").style.display = "block";

    document.getElementById("rig_0_operateModeIndicator").textContent = "VFO A";
    document.getElementById("rig_1_operateModeIndicator").textContent = "VFO A";
  }

  setPowerOn(powerOn = !this.arrDisplay[this.selectedDisplayIndex].objRadio._powerOn) {
    const b = document.getElementById("rig_powerButtonIndicator");

    if (powerOn && !this.arrDisplay[this.selectedDisplayIndex].objRadio._powerOn) {
      b.className.baseVal = "blinking-power-indicator-on";
      //b.className.animVal = "blinking-power-indicator-on";
    } else {
      b.className.baseVal = "blinking-power-indicator-off";
      //b.className.animVal = "blinking-power-indicator-off";
    }

    /*
    if (powerOn) {
      b.style.fill = "#ccff66";
    } else {
      b.style.fill = "#be0000";
    }
    */
    this.arrDisplay[this.selectedDisplayIndex].objRadio.powerOn(powerOn);
  }

  transmit() {
    // Toggle Transmit on active VFO...
    this.arrDisplay[this.selectedDisplayIndex].objRadio.txOn();
  }

  selectDisplay(displaySlot) {
    switch(displaySlot) {
      case DisplaySlot.A:
        this.selectedDisplayIndex = this.displayA_arrDisplayIndex;
        this.activeDisplaySlot = DisplaySlot.A;
        break;
      case DisplaySlot.B:
        this.selectedDisplayIndex = this.displayB_arrDisplayIndex;
        this.activeDisplaySlot = DisplaySlot.B;
        break;
      default:
        this.selectedDisplayIndex = this.displayA_arrDisplayIndex;
        this.activeDisplaySlot = DisplaySlot.A;
        console_error(`hmiRigsPage.selectDisplay(${displaySlot}): Invalid DisplaySlot provided...`);
        break;
    }

    let address = this.arrDisplay[this.selectedDisplayIndex].objRadio.address;

    this.selectModel(address, displaySlot);


    //  Still need these?
    //this.highlightSelectedRig(this.arrDisplay[this.selectedDisplayIndex].objRadio.address);
  }

  incrementFilter(displaySlot) {
    let index = -1;
    switch (displaySlot) {
      case DisplaySlot.A:
        index = this.displayA_arrDisplayIndex;
        break;
      case DisplaySlot.B:
        index = this.displayB_arrDisplayIndex;
        break;
    }

    this.arrDisplay[index].incrementFilter();
  }

  selectMode(modeName) {

    this.arrDisplay[this.selectedDisplayIndex].selectMode(modeName);
  }

  selectBand(band) {

    this.arrDisplay[this.selectedDisplayIndex].selectBand(band);
  }

  splitButtonToggle() {

    this.arrDisplay[this.selectedDisplayIndex].splitButtonToggle();
  }

  toggleDataMode(setNewMode) {

    this.arrDisplay[this.selectedDisplayIndex].toggleDataMode(setNewMode);
  }

  toggleVfoSide() {

    this.arrDisplay[this.selectedDisplayIndex].toggleVfoSide();
  }

  operateModeToggle() {

    this.arrDisplay[this.selectedDisplayIndex].operateModeToggle();
  }

  /*   DELETE THIS FUNCTION
  toneButtonToggle() {

    //this.arrDisplay[this.selectedDisplayIndex].toneButtonToggle();
  }
  */

  giveFocus(element) {
    let boolIsObject = false;
    const existingFocus = this.focusElement;

    // Determine if element is a HTML Element or an ID name...
    if (typeof element === "object") {
      boolIsObject = true;
    }
    else if (typeof element === "string") {
      //console_error(`element ID =  ${element}`);
      boolIsObject = false;
    }
    else {
      console_error(`unknown element: ${element}`);
      return;
    }

    if (!boolIsObject) {
      element = document.getElementById(element);
    }

    if (existingFocus === element) {
      // Remove Focus...
      this.clearFocus();
    }
    else {
      switch (element.id) {
        case "rig_panel_repeater_rx_tone_value":
          // Apply Focus...
          let box = document.getElementById(element.id + "_highlight");
          box.setAttribute("stroke", "yellow");
          this.focusElement = element;
          console_info(`Focus given to ${element.id}`);
          break;

        default:
          break;
      }
    }
  }

  clearFocus() {
    if (typeof this.focusElement === "object" && this.focusElement != null) {
      // Handle any actions related to removing focus on an element...
      switch (this.focusElement.id) {
        case "rig_panel_repeater_rx_tone_value":
          let box = document.getElementById(this.focusElement.id + "_highlight");
          box.setAttribute("stroke", "#444");
          break;

        default:
          console_warn("clearFocus():  No custom action taken...")
          break;
      }

      console_info(`Focus removed from ${this.focusElement.id}`)
      this.focusElement = null;
    }
  }

  refreshRepeaterDetails() {
    const display = this.arrDisplay[this.selectedDisplayIndex];
    const radio = display.objRadio;
    radio.requestRepeaterDetails();
    setTimeout(() => {
      display.updateRepeaterDisplay();
    }, 800);
  }

  changeToneValue(boolNext, boolTxSide) {
    const radio = this.arrDisplay[this.selectedDisplayIndex].objRadio;
    radio.changeToneValue(boolNext, boolTxSide);
  }

  changeToneType(toneType, boolTxSide) {
    const radio = this.arrDisplay[this.selectedDisplayIndex].objRadio;
    radio.changeToneType(toneType, boolTxSide);
  }

  changeDuplex(boolDuplex, boolShiftUp) {
    const radio = this.arrDisplay[this.selectedDisplayIndex].objRadio;
    radio.changeDuplex(boolDuplex, boolShiftUp);
  }

  changeDtcsPolarity(boolTxSide) {
    const radio = this.arrDisplay[this.selectedDisplayIndex].objRadio;
    radio.changeDtcsPolarity(boolTxSide);
  }

  toggleScope() {

    this.arrDisplay[this.selectedDisplayIndex].toggleScope();
  }
}




class hmiRig {
  boolActiveDisplay = false;
  subBandVisible = false;
  subBandHideTimer = null;
  objRadio;
  boolDisplay = false;
  displayIndex = -1;
  displaySlot = DisplaySlot.None;
  #eventTarget = new EventTarget();
  savedRepeaterState;
  checkPowerInterval = 2000;
  boolScope = false;

  constructor(objRadio) {
    this.objRadio = objRadio;

    // Rig Event Handling...
    this.objRadio.addEventListener('rig_event', (e) => { this.handleRigEvent(e);});

    // Check for power indicator updates 
    setInterval(() => {this.updatePowerStatus();}, this.checkPowerInterval); 
  }

  updatePowerStatus() {
    const powerOn = this.objRadio._powerOn;
    const poweringState = this.objRadio._poweringState;
  
    const currentDate = Date.now();
    const lastDate = this.objRadio._lastResponseDt.valueOf();
    const diffDate = currentDate - lastDate;
  
    if (this.objRadio.polls.length > 1) {
      if (diffDate > 3000) {
        switch (poweringState) {
          case PoweringState.On:
          case PoweringState.Off:
          case PoweringState.Unknown:
          case PoweringState.TurningOff:
            this.objRadio._powerOn = false;
            this.objRadio._poweringState = PoweringState.Off;
            break;

          case PoweringState.TurningOn:
            // do nothing...
            break;
        }
      }
      else {
        switch (poweringState) {
          case PoweringState.On:
          case PoweringState.Off:
          case PoweringState.Unknown:
          case PoweringState.TurningOn:
            this.objRadio._powerOn = true;
            this.objRadio._poweringState = PoweringState.On;
            break;

          case PoweringState.TurningOff:
            // do nothing...
            break;
        }
      }

      this.updateElement("power");
    }
  }

  handleRigEvent(e) {
    console_log(`${e.detail.rig._type} device fired ${e.detail.value} event`);

    switch (e.detail.value) {
      case "WebSocket":
        switch (e.detail.readyState) {
          case "CONNECTING":
          case "CLOSING":
            document.getElementById("rig_circle_status").style.fill = "yellow";
            break;
          case "OPEN":
            document.getElementById("rig_circle_status").style.fill = "green";
            break;
          case "CLOSED":
            document.getElementById("rig_circle_status").style.fill = "red";
            break;
        }

      case "socketOpen":
        document.getElementById("rig_circle_status").style.fill = "green";
        //e.detail.rig.initialize();
        break;
        
      case "socketClose":
        document.getElementById("rig_circle_status").style.fill = "red";
        break;
        
      case "TX":
      case "freq":
      case "mode":
      case "filter":
      case "dataMode":
      case "split":
      case "turning_on":
      case "turning_off":
      case "smeter":
      case "pometer":
      case "swrmeter":
      case "voltage":
      case "amperage":
      case "tone":
      case "scopeIsOn":
      case "scopeIsSending":
      case "scopeData":
        this.updateElement(e.detail.value);
        break;

      case "RX":
        this.updateElement("RX");
        this.updateElement("pometer");
        this.updateElement("swrmeter");
        break;

      case "power":
        this.updateElement("power");
        this.updateElement("freq");

      default:
        console_log("rig.js::Rig Event Handling - unknown event");
        break;
    }
  }

  /****************************************************************************
   * Function:    updateElement 
   * Parameters:  element       - display element to update, or "ALL"
   *              displaySlot^  - 
   *
   * Description: Will update a portion of the display based on displaySlot, if
   *              no displaySlot is specified, the active display will be used.
   *
   * ^ - Optional parameter
   * **************************************************************************/
  updateElement(element, displaySlot) {
    const slot = (displaySlot == undefined) ? `${this.displaySlot}` : displaySlot;
    const radio =  this.objRadio;
    let vfoIndex = this.objRadio._activeVFOIndex;
    let inactiveVfoIndex = this.objRadio._inactiveVFOIndex;
    let vfo = this.objRadio._arrVFO[vfoIndex];
    let otherVfo = this.objRadio._arrVFO[inactiveVfoIndex];

    let slotLetter = "";
    switch (slot) { // Set Slot Letter
      case "0":
        slotLetter = "A";
        break;
      case "1":
        slotLetter = "B";
        break;
      default:
        console_error(`hmiRig.updateElement(${element}): unknown slot - ${slot}`);
    }

    if (this.boolDisplay && this.displayIndex >= 0) {
      if (element == "TX" || element == "RX" || element == "squelch" || element == "ALL") {

        this.setTXIndicatorOn(vfo.tx);
      }
            
      if (element == "freq" || element == "ALL") {
        let freq = vfo._frequency;
        //if (!radio._powerOn) freq = "0.000.000";


        document.getElementById(`rig_${slot}_Band`).style.display = "block";
        document.getElementById(`rig_${slot}_bandIndicators`).style.display = "block";
        let last = freq.slice(-1);
        let rest = freq.slice(0, -1);
        let first = rest.split(".")[0] + ".";
        rest = rest.replace(first, "");
        let frequencyHtml = "<tspan style=\"font-size:38px;\"";
        frequencyHtml += " onclick=\"hmi_open_popup('hmi_rig_panel_band'"
        frequencyHtml += `, DisplaySlot.${slotLetter})">`;
        frequencyHtml += first;
        frequencyHtml += "</tspan>";
        frequencyHtml += rest;
        frequencyHtml += '<tspan style="font-size:22px;">';
        frequencyHtml += last;
        frequencyHtml += "</tspan>";
        document.getElementById(`rig_${slot}_mainFrequency`).innerHTML = frequencyHtml;

        // Split/Duplex Frequency...
        let splitFreq = otherVfo._frequency;
        let splitLast = splitFreq.slice(-1);
        let splitRest = splitFreq.slice(0, -1);
        let splitFirst = splitRest.split(".")[0] + ".";
        splitRest = splitRest.replace(splitFirst, "");
        //let splitFrequencyHtml = splitFirst+splitRest+splitLast;
        let splitFrequencyHtml = splitFirst;
        splitFrequencyHtml += splitRest;
        splitFrequencyHtml += '<tspan style="font-size:10px;">';
        splitFrequencyHtml += splitLast;
        splitFrequencyHtml += "</tspan>";
        document.getElementById(`rig_${slot}_subFrequency`).innerHTML = splitFrequencyHtml;
      }

      if (element == "filter" || element == "ALL") {
        let filter = vfo._filter;
        let btnFilter = document.getElementById(`rig_${slot}_filterBtnLabel`);

        btnFilter.textContent = filter;
      }

      if (element == "mode" || element == "dataMode" || element == "ALL") {
        let btnMode = document.getElementById(`rig_${slot}_modeBtnLabel`);
        const boolDataMode = vfo._data;
        let strData = "";
        let strMode = vfo._mode;

        if (boolDataMode) {
          strData = "-D";
        }

        btnMode.textContent = strMode + strData;
      }

      if (element == "split" || element == "ALL") {
        const splitBtn = document.getElementById("rig_splitBtnLabel");
        const duplexIndicator = document.getElementById(`rig_${slot}_bandIndicators_duplex`);

        if (this.boolActiveDisplay) {
          if (vfo._split) {
            splitBtn.setAttribute("fill", "#FFA500");
          } else {
            splitBtn.setAttribute("fill", "#fff");
          }
        }

        if (vfo.simplex) {
          if (vfo._split) {
            duplexIndicator.textContent = "SPLIT";
          }
          else {
            duplexIndicator.textContent = "";
          }
        }
        else if (vfo.duplexUp) {
          duplexIndicator.textContent = "DUP+";
        }
        else if (vfo.duplexDown) {
          duplexIndicator.textContent = "DUP-";
        }
        else {
         duplexIndicator.textContent = "???"; 
        }

        if (this.boolActiveDisplay) {
          this.updateRepeaterDisplay();
        }
      }

      if (element == "power" || element == "turning_on" || element == "turning_off" || element == "ALL") {
        const btnPower = document.getElementById("rig_powerButtonIndicator");

        if (radio.active) {
          switch (radio._poweringState) {
            case PoweringState.On:
              btnPower.className.baseVal = "solid-power-indicator-on";
              //btnPower.className.animVal = "";
              break;

            case PoweringState.Off:
              btnPower.className.baseVal = "solid-power-indicator-off";
              //btnPower.className.animVal = "";
              break;
              
            case PoweringState.TurningOn:
              btnPower.className.baseVal = "blinking-power-indicator-on";
              //btnPower.className.animVal = "blinking-power-indicator-on";
              break;
              
            case PoweringState.TurningOff:
              btnPower.className.baseVal = "blinking-power-indicator-off";
              //btnPower.className.animVal = "blinking-power-indicator-off";
              break;
              
            case PoweringState.Unknown:
              btnPower.className.baseVal = "blinking-power-indicator-off";
              //btnPower.className.animVal = "blinking-power-indicator-off";
              break;
          }
        }
      }

      if (element == "smeter" || element == "ALL") {
        let poMeter = document.getElementById(`rig_${slot}_poValue`);
        if (!vfo.tx) {
          rig_updateSegmentedMeter(`rig_${slot}_spoMeterGroup`, scaleSMeter(vfo._smeter), "blue", "red");
          poMeter.textContent = `${scaleSMeter(vfo._smeter, false)}`; // Signal
        }
        else {
          poMeter.textContent = scalePO(vfo._pometer).toPrecision(3) + "w";
        }
      }

      if (element == "pometer" || element == "ALL") {
        let poMeter = document.getElementById(`rig_${slot}_poValue`);
        const poValue = scalePO(vfo._pometer).toPrecision(3);

        if (vfo.tx) {
          poMeter.textContent = poValue + "w";
          rig_updateSegmentedMeter(`rig_${slot}_spoMeterGroup`, vfo._pometer, "red");
        }
        else {
          poMeter.textContent = `${scaleSMeter(vfo._smeter, false)}`; // Signal
        }
      }

      if (element == "swrmeter" || element == "ALL") {
        let swrMeter = document.getElementById(`rig_${slot}_swrValue`);
        const swrValue = getSWR(vfo._swrmeter).toPrecision(3);
        if (vfo.tx) { 
          swrMeter.textContent = "SWR: " + swrValue;
        }
        else {
          swrMeter.textContent = "SWR: ";
        }
      }

      if (element == "voltage" || element == "ALL") {
        let voltageMeter = document.getElementById(`rig_${slot}_voltageValue`);
        const voltageValue = getVoltage(radio._voltage).toPrecision(3);
        voltageMeter.textContent = voltageValue + " VDC";
      }

      if (element == "amperage" || element == "ALL") {
        let amperageMeter = document.getElementById(`rig_${slot}_amperageValue`);
        const amperageValue = getAmps(radio._amperage).toPrecision(3);
        if (amperageValue < 1) {
          amperageMeter.textContent = amperageValue * 1000 + " mA";
        }
        else {
          amperageMeter.textContent = amperageValue + " A";
        }
      }

      if (element == "tone" || element == "ALL") {
        const toneIndicator = document.getElementById(`rig_${slot}_bandIndicators_tone`);
        let toneType = "???";

        if (!vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          toneType = ""; // No Tone/DTCS Enabled
        }
        else if (vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          switch(radio.radioType) { 
            case Radio_Type.IC_7300:
              if (vfo._mode == "FM") {
                toneType = "TONE"; // TX Tone Enabled
              }
              else {
                toneType = ""; // Hide TX Tone State
              }
              break;
            case Radio_Type.IC_9700:
            default:
              toneType = "TONE"; // TX Tone Enabled
              break;
          }
        }
        else if (!vfo.txToneEnabled && vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          switch(radio.radioType) {
            case Radio_Type.IC_7300:
              if (vfo._mode == "FM") {
                toneType = "TSQL"; // TX Tone Enabled
              }
              else {
                toneType = ""; // Hide TX Tone State
              }
              break;
            case Radio_Type.IC_9700:
            default:
              toneType = "TSQL"; // TX Tone Enabled
              break;
          }
        }
        else if (!vfo.txToneEnabled && !vfo.rxToneEnabled && vfo.txDtcsEnabled && vfo.rxDtcsEnabled) {
          toneType = "DTCS"; // DTCS Enabled
        }
        else if (!vfo.txToneEnabled && !vfo.rxToneEnabled && vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          toneType = "(DTCS)"; // TX DTCS Enabled (blinking "DTCS")
        }
        else if (vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && vfo.rxDtcsEnabled) {
          toneType = "(T)-DTCS"; // TX Tone / RX DTCS Enabled (blinking "T")
        }
        else if (!vfo.txToneEnabled && vfo.rxToneEnabled && vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          toneType = "(D)-TSQL"; // TX DTCS / RX Tone Enabled (blinking "D")
        }
        else if (vfo.txToneEnabled && vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
          toneType = "(T)-TSQL"; // TX Tone / RX Tone Enabled (blinking "T")
        }

        toneIndicator.innerHTML = toneType;

        if (this.boolActiveDisplay) {
          this.updateRepeaterDisplay();
        }
      }

      if (element == "scopeIsOn" || element == "ALL") {
        const btnScope = document.querySelector("#rig_scopeButton text");
        if (vfo.scopeIsOn) {
          console.log("Scope is turned on");
          btnScope.setAttribute("fill", "#FFA500");
        }
        else {
          console.log("Scope is turned off");
          btnScope.setAttribute("fill", "#fff");
        }
      }

      if (element == "scopeIsSending" || element == "ALL") {
        const scopePanel = document.getElementById("rig_scopePanel");
        if (vfo.scopeIsSending) {
          console.log("Scope is sending data");
          if (this.displaySlot == DisplaySlot.A) {
            scopePanel.setAttribute("transform", "translate(95,173) scale(0.76)");
          }
          else if (this.displaySlot == DisplaySlot.B) {
            scopePanel.setAttribute("transform", "translate(95,50) scale(0.76)");
          }

          scopePanel.style.display = "block";
        }
        else {
          console.log("Scope is no longer sending ");
          scopePanel.style.display = "none";
        }
      }

      if (element == "scopeData" || element == "ALL") {
        if (vfo.scopeIsOn && vfo.scopeIsSending) {
          //console.log(`Scope Data received: ${vfo.scopeData}`);
          this.generateWaterfallRow();
        }
        else {
          console.log("Scope Data event detected but scope is marked as either off or not sending...");
        }
      }

      // Show/hide sub frequency...
      this.toggleSubFrequency();
    }
  }

  generateWaterfallRow() {
    const radio =  this.objRadio;
    const vfoIndex = this.objRadio._activeVFOIndex;
    const vfo = this.objRadio._arrVFO[vfoIndex];
    const maxRows = 125;
    const svgNamespace = "http://www.w3.org/2000/svg";
    const waterfall = document.getElementById("rig_scopePanel_waterfall_data");


    // Create a row for the waterfall with current data...
    const row = document.createElementNS(svgNamespace, "g");
    row.id = "testrow_" + waterfall.children.length;
    row.setAttribute("transform", "translate(0,0)");

    for (let i = 0; i < vfo.scopeData.length; i++) {
      // create SVG circle
      let dot = document.createElementNS(svgNamespace, "circle");
      // <circle cx="1" cy="1" r="1" fill="red" />
      dot.setAttribute("cx", i);
      dot.setAttribute("cy", "0");
      dot.setAttribute("r", "1");
      dot.setAttribute("fill", this.getWaterfallColor(vfo.scopeData[i]));
      dot.setAttribute("fill-opacity", this.getWaterfallOpacity(vfo.scopeData[i]))
      row.appendChild(dot);
    }

    waterfall.insertBefore(row, waterfall.children[0]);
    if (waterfall.children.length > maxRows) {
      for (let i = waterfall.children.length - 1; i > maxRows; i--) {
        waterfall.children[i].remove();
      }
    }
    for (let i = 0; i < waterfall.children.length; i++) {
      const row = waterfall.children[i];
      row.setAttribute("transform", "translate(0," + i + ")");
    }

    //waterfall.appendChild(row);
  }

  getWaterfallOpacity(hexString) {
    const number = parseInt(hexString, 16); // 0 - 255
    const scale = 2.0;
    const percent = number / 255.0 / scale;

    return 0.5 + percent.toFixed(2);
    return 1.0;
  }

  getWaterfallColor(hexString) {
    const number = parseInt(hexString, 16); // 0 - 255
    //const hexadecimalString = number.toString(16); // 00 - FF
    const scale = 20;

    let fullDecValue = number * scale;

    let rValue = 0;
    let gValue = 0;
    let bValue = 0;

    // increase Blue level...
    if (fullDecValue > 255) {
      bValue = 255;
    }
    else {
      bValue = fullDecValue;
    }
    fullDecValue = fullDecValue - bValue;

    // increase Green level...
    if (fullDecValue > 255) {
      gValue = 255;
    }
    else {
      gValue = fullDecValue;
    }
    fullDecValue = fullDecValue - gValue;

    // decrease Blue level...
    if (fullDecValue > 255) {
      bValue = 0;
    }
    else {
      bValue = bValue - fullDecValue;
    }
    if (fullDecValue > 0) {
      fullDecValue = fullDecValue - (255 - bValue);
    }

    // increase Red level...
    if (fullDecValue > 255) {
      rValue = 255;
    }
    else {
      rValue = fullDecValue;
    }
    fullDecValue = fullDecValue - rValue;

    // decrease Green level...
    if (fullDecValue > 255) {
      gValue = 0;
    }
    else {
      gValue = gValue - fullDecValue;
    }
    if (fullDecValue > 0) {
      fullDecValue = fullDecValue - (255 - gValue);
    }

    // increase Blue level...
    if (fullDecValue > 255) {
      bValue = 255;
    }
    else if (fullDecValue > 0) {
      bValue = fullDecValue;
    }
    fullDecValue = fullDecValue - bValue;

    // increase Green level...
    if (fullDecValue > 255) {
      gValue = 255;
    }
    else if (fullDecValue > 0) {
      gValue = fullDecValue;
    }
    fullDecValue = fullDecValue - gValue;

    let hexRed = rValue.toString(16); // 00 - FF
    let hexGreen = gValue.toString(16); // 00 - FF
    let hexBlue = bValue.toString(16); // 00 - FF

    if (hexRed.length == 1) hexRed = "0" + hexRed;
    if (hexGreen.length == 1) hexGreen = "0" + hexGreen;
    if (hexBlue.length == 1) hexBlue = "0" + hexBlue;

    return "#" + hexRed + hexGreen + hexBlue;
  }

  toggleSubFrequency(){
    const slot = `${this.displaySlot}`;
    const radio =  this.objRadio;
    let vfoIndex = this.objRadio._activeVFOIndex;
    let vfo = this.objRadio._arrVFO[vfoIndex];

    if (vfo._split || !vfo.simplex) {
      document.getElementById(`rig_${slot}_subFrequency`).style.display = "block";
    }
    else {
      document.getElementById(`rig_${slot}_subFrequency`).style.display = "none";
    }
  }

  setTXIndicatorOn(boolTX = true) {
    const dId = `${this.displaySlot}`; // Determine Display ID
    const a = document.getElementById(`rig_${dId}_txRect`);
    const b = document.getElementById(`rig_${dId}_txText`);
    const c = document.getElementById(`rig_transmitButtonIndicator`);
    let vfoIndex = this.objRadio._activeVFOIndex;
    let vfo = this.objRadio._arrVFO[vfoIndex];

    if (boolTX) {
      a.style.fill = "red";
      a.style.stroke = "white";
      b.style.fill = "white";
      b.innerHTML = "TX";
      if (this.objRadio.active) {
        c.style.fill = "red";
      }
    } else {
      a.style.fill = "none";
      if (vfo._squelch) {
        a.style.stroke = "#ccff66";
        b.style.fill = "#ccff66";
      }
      else {
        a.style.stroke = "#333333";
        b.style.fill = "#333333";
      }
      b.innerHTML = "RX";
      if (this.objRadio.active) {
        c.style.fill = "#555";
      }
    }
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

  incrementFilter() {
    const radio = this.objRadio;
    const vfo = radio._arrVFO[radio._activeVFOIndex];

    const newFilterIndex = (vfo._currentFilterIndex + 1) % radio.filterList.length;
    const newFilterValue = radio.filterList[newFilterIndex];

    radio.updateMode(null, newFilterValue, null, true);
  }

  selectMode(modeName) {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];

    let filterValue = radio.filterList[vfo._currentFilterIndex];
    let dataMode = vfo._dataMode;
    let modeValue = "00";

    switch (modeName) {
      case "LSB":
        modeValue = "00";
        break;
      case "USB":
        modeValue = "01";
        break;
      case "AM":
        modeValue = "02";
        break;
      case "CW":
        modeValue = "03";
        break;
      case "RTTY":
        modeValue = "04";
        break;
      case "FM":
        modeValue = "05";
        break;
      case "CW-R":
        modeValue = "07";
        break;
      case "RTTY-R":
        modeValue = "08";
        break;
      case "DV":
        modeValue = "17";
        break;
      case "DD":
        modeValue = "22";
        break;
    }

    radio.updateMode(modeValue, filterValue, dataMode, true);
  }

  selectBand(band) {
    const radio = this.objRadio;
    let bandIndex = 0;
    let stackIndex = 0;

    switch (band) {
      case "1.8":
        radio.sendCommand("1A 01 01 01");
        bandIndex = 0;
        break;
      case "3.5":
        radio.sendCommand("1A 01 02 01");
        bandIndex = 1;
        break;
      case "7":
        radio.sendCommand("1A 01 03 01");
        bandIndex = 2;
        break;
      case "10":
        radio.sendCommand("1A 01 04 01");
        bandIndex = 3;
        break;
      case "14":
        radio.sendCommand("1A 01 05 01");
        bandIndex = 4;
        break;
      case "18":
        radio.sendCommand("1A 01 06 01");
        bandIndex = 5;
        break;
      case "21":
        radio.sendCommand("1A 01 07 01");
        bandIndex = 6;
        break;
      case "24":
        radio.sendCommand("1A 01 08 01");
        bandIndex = 7;
        break;
      case "28":
        radio.sendCommand("1A 01 09 01");
        bandIndex = 8;
        break;
      case "50":
        radio.sendCommand("1A 01 10 01");
        bandIndex = 9;
        break;
      case "144":
        radio.sendCommand("1A 01 01 01");
        bandIndex = 0;
        break;
      case "430":
        radio.sendCommand("1A 01 02 01");
        bandIndex = 1;
        break;
      case "1240":
        radio.sendCommand("1A 01 03 01");
        bandIndex = 2;
        break;
    }

    setTimeout(()=>{
      radio.setFrequency(radio.bandStackingList[bandIndex][stackIndex]);
    }, 200);

    setTimeout(()=>{
      radio.sendCommand("03");
    }, 400);
  }

  splitButtonToggle() {
    const radio = this.objRadio;
    const vfoIndex = radio._activeVFOIndex;
    const vfo = radio._arrVFO[vfoIndex];
    const splitValue = "0" + vfo._splitMode;

    let newVal = (splitValue == "00") ? "01" : "00";
    if (splitValue !== "00" && splitValue !== "01") newVal = "01";

    radio.sendCommand(`0F ${newVal}`);

    //setTimeout(rig_send0FCommand, 600);
    setTimeout(() => {radio.send0FCommand();}, 200);
  }

  toggleDataMode(setNewMode) {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];
    const oldMode = vfo._dataMode;
    if (setNewMode == undefined) {
      setNewMode = (oldMode + 1) % 2;
    }

    radio.updateMode(null, null, setNewMode, true);
  }

  toggleVfoSide() {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];


    if (vfoIndex == VFOSide.A) {
      this.selectVfo(VFOSide.B);
    } else {
      this.selectVfo(VFOSide.A);
    }
  }

  selectVfo(vfoSide) {
    const radio = this.objRadio;
    let vfoLetter = "A";

    if (radio._operateMode != OperateMode.VFO && vfoSide == undefined) {
      // Switch rig to VFO Mode
      radio.sendCommand('07');
    } else if (vfoSide == VFOSide.A) {
      radio.sendCommand('07 00');
    } else if (vfoSide == VFOSide.B) {
      radio.sendCommand('07 01');
    } else {
      radio.sendCommand('07 00');
      console_error(`hmiRig.selectVfo(${vfoSide}): Invalid VFOSide condition...`);
      vfoSide = VFOSide.A;
    }
    radio._activeVFOIndex = vfoSide;
    radio._inactiveVFOIndex = (vfoSide + 1) % 2;

    /*
    //setTimeout(() => {radio.sendFrequencyQuery();}, 200);
    //setTimeout(() => {radio.sendDefaultMode();}, 400);
    setTimeout(() => {radio.sendCommand("25 00");}, 100);
    setTimeout(() => {radio.sendCommand("26 00");}, 100);
    setTimeout(() => {radio.sendCommand("25 01");}, 200);
    setTimeout(() => {radio.sendCommand("26 01");}, 200);
    */
    radio.sendCommand("25 00");
    radio.sendCommand("26 00");
    radio.sendCommand("25 01");
    radio.sendCommand("26 01");

    if (vfoSide == undefined) vfoSide = VFOSide.A;
    switch (vfoSide) {
      case VFOSide.A:
        vfoLetter = "A";
        break;
      case VFOSide.B:
        vfoLetter = "B";
        break;
      default:
        console_error(`hmiRig.selectVfo(${vfoSide}): Unable to determine VFO Letter...`);
    }

    document.getElementById(`rig_${this.displaySlot}_operateModeIndicator`).textContent = `VFO ${vfoLetter}`;
  }

  operateModeToggle() {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];

    if (radio._operateMode == OperateMode.VFO) {
      radio.sendCommand('08');
      setTimeout(() => {radio.sendFrequencyQuery();}, 200);
      radio._operateMode = OperateMode.MEM;
      document.getElementById(`rig_${this.displaySlot}_operateModeIndicator`).textContent = "MEM " + parseInt(radio._memoryCH, 10);
    } else {
      this.selectVfo(radio._activeVFOIndex);
      radio._operateMode = OperateMode.VFO;
    }
  }

  updateRepeaterDisplay() {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];

    let btnTxOff = document.getElementById("hmi_rig_panel_repeater_tx_off_button");
    let btnTxTone = document.getElementById("hmi_rig_panel_repeater_tx_tone_button");
    let btnTxDtcs = document.getElementById("hmi_rig_panel_repeater_tx_dtcs_button");
    let btnRxOff = document.getElementById("hmi_rig_panel_repeater_rx_off_button");
    let btnRxTone = document.getElementById("hmi_rig_panel_repeater_rx_tone_button");
    let btnRxDtcs = document.getElementById("hmi_rig_panel_repeater_rx_dtcs_button");
    let textTxValue = document.getElementById("rig_panel_repeater_tx_tone_value");
    let textRxValue = document.getElementById("rig_panel_repeater_rx_tone_value");
    let btnSimplex = document.getElementById("rig_panel_repeater_simplex_button");
    let btnDupUp = document.getElementById("rig_panel_repeater_duplex_up_button");
    let btnDupDown = document.getElementById("rig_panel_repeater_duplex_down_button");
    let btnTxPolarity = document.getElementById("rig_panel_repeater_tx_polarity_button");
    let textTxPolarity = document.getElementById("rig_panel_repeater_tx_polarity_value");
    let btnRxPolarity = document.getElementById("rig_panel_repeater_rx_polarity_button");
    let textRxPolarity = document.getElementById("rig_panel_repeater_rx_polarity_value");

    const fillBlue = "url(#rig_blueGradient)";
    const fillOrange = "url(#rig_orangeGradient)";
    const fillNone = "";

    // Display TX/RX Tone/DTCS
    if (!vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 00
      btnTxOff.setAttribute("fill", fillOrange);
      btnTxTone.setAttribute("fill", fillNone);
      btnTxDtcs.setAttribute("fill", fillNone);
      btnRxOff.setAttribute("fill", fillOrange);
      btnRxTone.setAttribute("fill", fillNone);
      btnRxDtcs.setAttribute("fill", fillNone);
    }
    else if (vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 01
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillBlue);
      btnTxDtcs.setAttribute("fill", fillNone);
      btnRxOff.setAttribute("fill", fillOrange);
      btnRxTone.setAttribute("fill", fillNone);
      btnRxDtcs.setAttribute("fill", fillNone);
    }
    else if (!vfo.txToneEnabled && vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 02
      btnTxOff.setAttribute("fill", fillOrange);
      btnTxTone.setAttribute("fill", fillNone);
      btnTxDtcs.setAttribute("fill", fillNone);
      btnRxOff.setAttribute("fill", fillNone);
      btnRxTone.setAttribute("fill", fillBlue);
      btnRxDtcs.setAttribute("fill", fillNone);
    }
    else if (!vfo.txToneEnabled && !vfo.rxToneEnabled && vfo.txDtcsEnabled && vfo.rxDtcsEnabled) {
      // 16 5D = 03
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillNone);
      btnTxDtcs.setAttribute("fill", fillBlue);
      btnRxOff.setAttribute("fill", fillNone);
      btnRxTone.setAttribute("fill", fillNone);
      btnRxDtcs.setAttribute("fill", fillBlue);
    }
    else if (!vfo.txToneEnabled && !vfo.rxToneEnabled && vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 06
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillNone);
      btnTxDtcs.setAttribute("fill", fillBlue);
      btnRxOff.setAttribute("fill", fillOrange);
      btnRxTone.setAttribute("fill", fillNone);
      btnRxDtcs.setAttribute("fill", fillNone);
    }
    else if (vfo.txToneEnabled && !vfo.rxToneEnabled && !vfo.txDtcsEnabled && vfo.rxDtcsEnabled) {
      // 16 5D = 07
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillBlue);
      btnTxDtcs.setAttribute("fill", fillNone);
      btnRxOff.setAttribute("fill", fillNone);
      btnRxTone.setAttribute("fill", fillNone);
      btnRxDtcs.setAttribute("fill", fillBlue);
    }
    else if (!vfo.txToneEnabled && vfo.rxToneEnabled && vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 08
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillNone);
      btnTxDtcs.setAttribute("fill", fillBlue);
      btnRxOff.setAttribute("fill", fillNone);
      btnRxTone.setAttribute("fill", fillBlue);
      btnRxDtcs.setAttribute("fill", fillNone);
    }
    else if (vfo.txToneEnabled && vfo.rxToneEnabled && !vfo.txDtcsEnabled && !vfo.rxDtcsEnabled) {
      // 16 5D = 09
      btnTxOff.setAttribute("fill", fillNone);
      btnTxTone.setAttribute("fill", fillBlue);
      btnTxDtcs.setAttribute("fill", fillNone);
      btnRxOff.setAttribute("fill", fillNone);
      btnRxTone.setAttribute("fill", fillBlue);
      btnRxDtcs.setAttribute("fill", fillNone);
    }

    if (vfo.simplex) {
      btnSimplex.setAttribute("fill", fillBlue);
    }
    else {
      btnSimplex.setAttribute("fill", fillNone); 
    }
    if (vfo.duplexUp) {
      btnDupUp.setAttribute("fill", fillBlue);
    }
    else {
      btnDupUp.setAttribute("fill", fillNone); 
    }
    if (vfo.duplexDown) {
      btnDupDown.setAttribute("fill", fillBlue);
    }
    else {
      btnDupDown.setAttribute("fill", fillNone); 
    }

    // Set values..
    if (vfo.txToneEnabled) {
      textTxValue.innerHTML = vfo.tone;
    }
    else if (vfo.txDtcsEnabled) {
      textTxValue.innerHTML = vfo.dtcs;
    }
    else {
      textTxValue.innerHTML = "--";
    }

    if (vfo.rxToneEnabled) {
      textRxValue.innerHTML = vfo.tsql;
    }
    else if (vfo.rxDtcsEnabled) {
      textRxValue.innerHTML = vfo.dtcs;
    }
    else {
      textRxValue.innerHTML = "--";
    }


    if (vfo.txDtcsEnabled) {
      btnTxPolarity.style.display = "block";
      textTxPolarity.textContent = (vfo.txPolarityNormal) ? "N" : "R";
    }
    else {
      btnTxPolarity.style.display = "none";
    }
    if (vfo.rxDtcsEnabled) {
      btnRxPolarity.style.display = "block";
      textRxPolarity.textContent = (vfo.rxPolarityNormal) ? "N" : "R";
    }
    else {
      btnRxPolarity.style.display = "none";
    }
  }

  saveRepeaterState() {
    const radio = this.objRadio
    const vfoIndex = this.objRadio._activeVFOIndex;
    const vfo = this.objRadio._arrVFO[vfoIndex];

    this.savedRepeaterState = {
      txToneEnabled: vfo.txToneEnabled,
      rxToneEnabled: vfo.rxToneEnabled,
      txDtcsEnabled: vfo.txDtcsEnabled,
      rxDtcsEnabled: vfo.rxDtcsEnabled,
      simplex: vfo.simplex,
      duplexUp: vfo.duplexUp,
      duplexDown: vfo.duplexDown,
      tone: vfo.tone,
      dtcs: vfo.dtcs
    }
  }

  restoreRepeaterState() {
    const radio = this.objRadio
    const vfoIndex = this.objRadio._activeVFOIndex;
    const vfo = this.objRadio._arrVFO[vfoIndex];


    if (this.savedRepeaterState.txToneEnabled) {
      radio.changeToneType("tone", true);
    }
    if (this.savedRepeaterState.rxToneEnabled) {
      radio.changeToneType("tone", false);
    }
    if (this.savedRepeaterState.txDtcsEnabled) {
      radio.changeToneType("dtcs", true);
    }
    if (this.savedRepeaterState.rxDtcsEnabled) {
      radio.changeToneType("dtcs", false);
    }
    if (!this.savedRepeaterState.txToneEnabled && !this.savedRepeaterState.txDtcsEnabled) {
      radio.changeToneType("off", true);
    }
    if (!this.savedRepeaterState.rxToneEnabled && !this.savedRepeaterState.rxDtcsEnabled) {
      radio.changeToneType("off", false);
    }

    if (this.savedRepeaterState.simplex) {
      radio.changeDuplex(false, false);
    }
    else if (this.savedRepeaterState.duplexUp) {
      radio.changeDuplex(true, true);
    }
    else if (this.savedRepeaterState.duplexDown) {
      radio.changeDuplex(true, false);
    }
    else {
      // unexpected condition
      console_error("hmiRig.restoreRepeaterState(): Unexpected condition...");
    }

    if (this.savedRepeaterState.txToneEnabled || this.savedRepeaterState.rxToneEnabled) {
      vfo.tone = this.savedRepeaterState.tone;
    }

    if (this.savedRepeaterState.txDtcsEnabled || this.savedRepeaterState.rxDtcsEnabled) {
      vfo.dtcs = this.savedRepeaterState.dtcs;
    }

    radio.sendToneValues();
  }

  toggleScope() {
    const radio = this.objRadio;
    let vfoIndex = radio._activeVFOIndex;
    let vfo = radio._arrVFO[vfoIndex];

    if (this.boolScope) {
      this.boolScope = false;
      radio.stopScope();
    }
    else {
      this.boolScope = true;
      radio.startScope();
    }

  }
}





window.addEventListener("DOMContentLoaded", () => { /* Set memLabels */
  const s = localStorage.getItem("memLabels");
  if (s) {
    memLabels = JSON.parse(s);
    for (let i = 0; i < 5; i++) {
      const btn = document.getElementById("memBtn" + i);
      if (btn) btn.textContent = memLabels[i];
    }
  }
});

window.addEventListener('DOMContentLoaded', () => { // Display A Meters SVG 
  // ---------------------------
  // 1) S/PO Meter (range 0–100) with dual scales
  // ---------------------------
  const spoGroup = document.getElementById('rig_0_spoMeterGroup');
  const spoConfig = {
    maxSegments: 101,
    minValue: 0,
    maxValue: 100,
    value: 50,
    segmentWidth: 2,
    gap: 1,
    segmentHeight: 10,
    baselineOffset: 2,
    filledColor: "blue",
    emptyColor: "#333",
    baselineColor: "white"
  };
  const spoInfo = rig_createSegmentedMeter(spoGroup, spoConfig);
  rig_drawBottomScale(spoGroup, spoInfo.totalWidth, spoInfo.baselineY, [0,20,40,60,80,100], {
    dotOffset: 4,
    textOffset: 12,
    fontSize: "10",
    label: "PO:"
  });
  rig_drawTopScale(spoGroup, spoInfo.totalWidth, {
    dotOffset: -4,
    textOffset: -12,
    fontSize: "10"
  });
});

window.addEventListener('DOMContentLoaded', () => { // Display B Meters SVG 
  // ---------------------------
  // 1) S/PO Meter (range 0–100) with dual scales
  // ---------------------------
  const spoGroup = document.getElementById('rig_1_spoMeterGroup');
  const spoConfig = {
    maxSegments: 101,
    minValue: 0,
    maxValue: 100,
    value: 50,
    segmentWidth: 2,
    gap: 1,
    segmentHeight: 10,
    baselineOffset: 2,
    filledColor: "blue",
    emptyColor: "#333",
    baselineColor: "white"
  };
  const spoInfo = rig_createSegmentedMeter(spoGroup, spoConfig);
  rig_drawBottomScale(spoGroup, spoInfo.totalWidth, spoInfo.baselineY, [0,20,40,60,80,100], {
    dotOffset: 4,
    textOffset: 12,
    fontSize: "10",
    label: "PO:"
  });
  rig_drawTopScale(spoGroup, spoInfo.totalWidth, {
    dotOffset: -4,
    textOffset: -12,
    fontSize: "10"
  });
});






function NOT_IN_USE__NEED_TO_REVISIT_WHEN_MAKING_LONG_PRESS_FOR_FILTER__rig_selectFilter(filterName) {
  let filterIndex = 0;
  switch (filterName) {
    case "FIL1":
      filterIndex = 0;
      break;
    case "FIL2":
      filterIndex = 1;
      break;
    case "FIL3":
      filterIndex = 2;
      break;
  }

  const newFilterValue = radio.filterList[filterIndex];
  arrRadio[rig_activeArrRadioIndex].updateMode(null, newFilterValue, null, true);
}

/**
 * Creates a segmented meter (bar plus baseline) in a given container.
 * Returns { totalWidth, baselineY, segmentHeight }.
 */
function rig_createSegmentedMeter(container, config) {
  config = config || {};
  const maxSegments   = config.maxSegments   ?? 101;
  const minValue      = config.minValue      ?? 0;
  const maxValue      = config.maxValue      ?? 100;
  const currentValue  = config.value         ?? 50;
  const segmentWidth  = config.segmentWidth  ?? 2;
  const gap           = config.gap           ?? 1;
  const segmentHeight = config.segmentHeight ?? 10;
  const baselineOffset= config.baselineOffset?? 2;
  const filledColor   = config.filledColor   ?? "blue";
  const emptyColor    = config.emptyColor    ?? "#333";
  const baselineColor = config.baselineColor ?? "white";

  container.innerHTML = "";

  for (let i = 0; i < maxSegments; i++) {
    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    const x = i * (segmentWidth + gap);
    rect.setAttribute("x", x);
    rect.setAttribute("y", 0);
    rect.setAttribute("width", segmentWidth);
    rect.setAttribute("height", segmentHeight);

    const segVal = minValue + i * (maxValue - minValue) / (maxSegments - 1);
    rect.setAttribute("fill", segVal <= currentValue ? filledColor : emptyColor);
    container.appendChild(rect);
  }

  const totalWidth = maxSegments * (segmentWidth + gap) - gap;
  const baselineY = segmentHeight + baselineOffset;
  const baseline = document.createElementNS("http://www.w3.org/2000/svg", "line");
  baseline.setAttribute("x1", 0);
  baseline.setAttribute("y1", baselineY);
  baseline.setAttribute("x2", totalWidth);
  baseline.setAttribute("y2", baselineY);
  baseline.setAttribute("stroke", baselineColor);
  baseline.setAttribute("stroke-width", "1");
  container.appendChild(baseline);

  return { totalWidth, baselineY, segmentHeight };
}

function rig_updateSegmentedMeter(meter, value, color = "blue", secondColor) {
  let m = document.getElementById(meter);
  let s = 0;
  secondColor = (!secondColor) ? color : secondColor;

  for (let i = 0; i < m.children.length; i++) {
    if (m.children[i].tagName == "rect") {
      s++;
    }
  }

  let v = s * (value / 100);



  for (let i = 0; i < s; i++) {
    if (i < v) {
      if (i >= s/2) {
        m.children[i].style.fill = secondColor;
      }
      else {
        m.children[i].style.fill = color;
      }
    } else {
      m.children[i].style.fill = "white";
    }
  }
}

/**
 * Draws a bottom scale below a meter.
 * Options: dotOffset, textOffset, fontSize, label, suffix.
 */
function rig_drawBottomScale(container, totalWidth, baselineY, scaleVals, options) {
  options = options || {};
  const dotOffset = options.dotOffset ?? 4;
  const textOffset = options.textOffset ?? 12;
  const fontSize = options.fontSize || "10";
  const suffix = options.suffix || "";
  const minScale = scaleVals[0];
  const maxScale = scaleVals[scaleVals.length - 1];

  scaleVals.forEach(val => {
    const ratio = (val - minScale) / (maxScale - minScale);
    const x = ratio * totalWidth;

    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", x);
    dot.setAttribute("cy", baselineY + dotOffset);
    dot.setAttribute("r", 2);
    dot.setAttribute("fill", "white");
    container.appendChild(dot);

    const txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
    txt.setAttribute("x", x - 8);
    txt.setAttribute("y", baselineY + textOffset);
    txt.setAttribute("fill", "white");
    txt.setAttribute("font-size", fontSize);
    txt.textContent = val + suffix;
    container.appendChild(txt);
  });

  if (options.label) {
    const lbl = document.createElementNS("http://www.w3.org/2000/svg", "text");
    lbl.setAttribute("x", -40);
    lbl.setAttribute("y", baselineY + textOffset);
    lbl.setAttribute("fill", "white");
    lbl.setAttribute("font-size", fontSize);
    lbl.textContent = options.label;
    container.appendChild(lbl);
  }
}

/**
 * Draws a top scale above a meter (the S scale).
 */
function rig_drawTopScale(container, totalWidth, options) {
  options = options || {};
  const dotOffset = options.dotOffset ?? -4;
  const textOffset = options.textOffset ?? -12;
  const fontSize = options.fontSize || "10";

  // "S:" label
  const sLabel = document.createElementNS("http://www.w3.org/2000/svg", "text");
  sLabel.setAttribute("x", -40);
  sLabel.setAttribute("y", textOffset);
  sLabel.setAttribute("fill", "white");
  sLabel.setAttribute("font-size", fontSize);
  sLabel.textContent = "S:";
  container.appendChild(sLabel);

  // Left half: 0..9
  const leftWidth = totalWidth / 2;
  for (let i = 0; i < 10; i++) {
    const x = (i / 9) * leftWidth;
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", x);
    dot.setAttribute("cy", dotOffset);
    dot.setAttribute("r", 2);
    dot.setAttribute("fill", "white");
    container.appendChild(dot);

    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", x - 6);
    text.setAttribute("y", textOffset);
    text.setAttribute("fill", "white");
    text.setAttribute("font-size", fontSize);
    text.textContent = i;
    container.appendChild(text);
  }

  // Right half: +10..+60
  const rightWidth = totalWidth / 2;
  for (let j = 0; j < 6; j++) {
    const x = leftWidth + (j / 5) * rightWidth;
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", x);
    dot.setAttribute("cy", dotOffset);
    dot.setAttribute("r", 2);
    dot.setAttribute("fill", "white");
    container.appendChild(dot);

    if (j > 0) {
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
      text.setAttribute("x", x - 10);
      text.setAttribute("y", textOffset);
      text.setAttribute("fill", "white");
      text.setAttribute("font-size", fontSize);
      text.textContent = "+" + ((j + 1) * 10);
      container.appendChild(text);
    }
  }
}

/**
 * Draws a custom bottom scale for the SWR meter (0..3 + ∞).
 */
function rig_drawSWRBottomScale(container, totalWidth, baselineY, options) {
  options = options || {};
  const dotOffset = options.dotOffset ?? 4;
  const textOffset = options.textOffset ?? 12;
  const fontSize = options.fontSize || "10";

  // Left half: 0..3
  const leftWidth = totalWidth / 2;
  for (let i = 0; i < 4; i++) {
    const x = (i / 3) * leftWidth;
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", x);
    dot.setAttribute("cy", baselineY + dotOffset);
    dot.setAttribute("r", 2);
    dot.setAttribute("fill", "white");
    container.appendChild(dot);

    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", x - 8);
    text.setAttribute("y", baselineY + textOffset);
    text.setAttribute("fill", "white");
    text.setAttribute("font-size", fontSize);
    text.textContent = i;
    container.appendChild(text);
  }

  // Right half: ∞ at the far right
  const dotRight = document.createElementNS("http://www.w3.org/2000/svg", "circle");
  dotRight.setAttribute("cx", totalWidth);
  dotRight.setAttribute("cy", baselineY + dotOffset);
  dotRight.setAttribute("r", 2);
  dotRight.setAttribute("fill", "white");
  container.appendChild(dotRight);

  const txtRight = document.createElementNS("http://www.w3.org/2000/svg", "text");
  txtRight.setAttribute("x", totalWidth - 10);
  txtRight.setAttribute("y", baselineY + textOffset);
  txtRight.setAttribute("fill", "white");
  txtRight.setAttribute("font-size", fontSize);
  txtRight.textContent = "∞";
  container.appendChild(txtRight);

  if (options.label) {
    const lbl = document.createElementNS("http://www.w3.org/2000/svg", "text");
    lbl.setAttribute("x", -40);
    lbl.setAttribute("y", baselineY + textOffset);
    lbl.setAttribute("fill", "white");
    lbl.setAttribute("font-size", fontSize);
    lbl.textContent = options.label;
  }
}





function scaleSMeter(value, returnPercent = true) {
  let s, p, t;
  if (value <= 120) {
    s = 9.0 * value / 120.0;
  }
  else if (value <= 241) {
    s = 9.0 + 6.0 * (value - 120) / 121.0;
  }
  else {
    s = 15.0;
  }
  p = (s / 18.0) * 100.0;


  if (s > 9.0) {
    t = s - 9.0;
    t = (t * 10).toFixed(0);
    s = `s9 +${t}`;
  }
  else {
    s = `s${s.toFixed(0)}`;
  }


  console_log("scaleSMeter -> value = " + value + ", units = " + s + ", percent = " + p);

  if (returnPercent) {
    return p;
  } else {
    return s;
  }
}

function scalePO(value) {
  if (value <= 143) {
    // 0% to 50%
    return (value / 143.0) * 50.0;
  } else if (value <= 213) {
    // 50% to 100%
    return 50.0 + ((value - 143) / 70.0) * 50.0;
  } else {
    // Over-range
    return 100.0;
  }
}

function getVoltage(value) {
  if (value <= 13) {
    // 0 to 10V
    return (value / 13.0) * 10.0;
  } else if (value <= 241) {
    // 10V to 16V
    return 10.0 + ((value - 13) / 228.0) * 6.0;
  } else {
    // Over-range
    return 16.0;
  }
}

function getAmps(value) {
  if (value <= 97) {
    // 0 to 10 A
    return (value / 97.0) * 10.0;
  } else if (value <= 146) {
    // 10 to 15 A
    return 10.0 + ( (value - 97) / 49.0) * 5.0;
  } else if (value <= 241) {
    // 15 to 25 A
    return 15.0 + ((value - 146) / 95.0) * 10.0;
  } else {
    // Over-range
    return 25.0;
  }
}

function getSWR(value) {
  if (value <= 48) {
    // SWR 1.0 - 1.5
    return 1.0 + (value / 48.0) * 0.5;
  } else if (value <= 80) {
    // SWR 1.5 - 2.0
    return 1.5 + ((value - 48) / 32.0) * 0.5;
  } else if (value <= 120) {
    // SWR 2.0 - 3.0
    return 2.0 + ((value - 80) / 40.0) * 1.0;
  } else {
    // Over-range
    return 3.0;
  }
}

function scaleSWR(value) {
  if (value <= 48) {
    // SWR 1.0 - 1.5
    return 1.0 + (value / 48.0) * 0.5;
  } else if (value <= 80) {
    // SWR 1.5 - 2.0
    return 1.5 + ((value - 48) / 32.0) * 0.5;
  } else if (value <= 120) {
    // SWR 2.0 - 3.0
    return 2.0 + ((value - 80) / 40.0) * 1.0;
  } else {
    // Over-range
    return 3.0;
  }
}

function scaleCOMP (value) {
  if (value <= 304) {
    // 0-15 dB segment
    return (value / 304.0) * 15.0;
  } else if (value <= 577) {
    // 15-30 dB segment
    return 15.0 + ( (value - 304) / 273.0) * 15.0;
  } else {
    //Over-range return
    return 30.0;
  }
}

function scaleALCpercent (value) {
  if (value <= 288) {
    return 100.0 * value / 288.0;
  } else {
    return 100.0;
  }
}

