/*----------------------------------------------------------------
  1) We keep an array of 10 antenna objects,
     each storing bandPattern + type/style/pol/mfg indices.
-----------------------------------------------------------------*/
let antennaState = new Array(10).fill(null).map(() => ({
  bandPattern: 0,
  typeIndex: 0,
  styleIndex: 0,
  polIndex: 0,
  mfgIndex: 0
}));

// The currently selected antenna index (0..9)
let currentAntennaIndex = 0;

// We store the antenna button labels for display only:
const antennaNames = [
  "GROUND",
  "40m Dipole",
  "IMAX Vertical",
  "Hanging Loop",
  "80m Dipole",
  "G5RV",
  "6m Vertical",
  "BENT",
  "BUSTED",
  "STOLEN"
];

// Optional: track if TYPE dropdown is open
let typeDropdownOpen = false;

/*----------------------------------------------------------------
  2) Local Storage Save/Load
-----------------------------------------------------------------*/
function saveAntennaData() {
  const dataToSave = {
    antennaState,
    currentAntennaIndex
  };
  localStorage.setItem('antennaData', JSON.stringify(dataToSave));
  console.log('Antenna data saved to localStorage:', dataToSave);
}

function loadAntennaData() {
  const dataString = localStorage.getItem('antennaData');
  if (!dataString) {
    console.log('No antenna data found in localStorage.');
    return;
  }
  try {
    const data = JSON.parse(dataString);
    if (!Array.isArray(data.antennaState) || data.antennaState.length !== 10) {
      console.log('antennaData invalid shape. Skipping load.');
      return;
    }
    antennaState = data.antennaState;
    currentAntennaIndex = data.currentAntennaIndex ?? 0;

    // Mark the corresponding antenna button as selected
    document.querySelectorAll('.antenna-button').forEach(b => b.classList.remove('selected'));
    const selButton = document.querySelector(`.antenna-button[data-index="${currentAntennaIndex}"]`);
    if (selButton) selButton.classList.add('selected');

    // Refresh UI for the loaded antenna
    refreshUIForAntenna(currentAntennaIndex);
    updateOptionButtons();
    console.log('Antenna data loaded from localStorage:', data);
  } catch (err) {
    console.error('Error parsing antenna data from localStorage:', err);
  }
}

/*----------------------------------------------------------------
  3) Helper Functions for LED, Tuner, UI updates
-----------------------------------------------------------------*/
function updateLEDsFromConfig(index) {
  const pattern = antennaState[index].bandPattern;
  document.querySelectorAll('.led').forEach((led, i) => {
    if (pattern & (1 << i)) {
      led.classList.remove('off');
      led.classList.add('on');
    } else {
      led.classList.remove('on');
      led.classList.add('off');
    }
  });
}

function updateTunerButton(index) {
  const tunerText = document.getElementById('tunerText');
  if (index === null) {
    tunerText.style.fill = '#fff';
    return;
  }
  const pattern = antennaState[index].bandPattern;
  tunerText.style.fill = (pattern & (1 << 14)) ? 'red' : '#fff';
}

function updateSelectedAntennaName(index) {
  const nameElem = document.getElementById("selectedAntennaName");
  const portNum = (index !== null) ? (index + 1) : "-";
  if (index === null) {
    nameElem.textContent = `Port ${portNum}: No Antenna Selected`;
  } else {
    nameElem.textContent = `Port ${portNum}: ${antennaNames[index]}`;
  }
}

function refreshUIForAntenna(index) {
  updateLEDsFromConfig(index);
  updateTunerButton(index);
  updateSelectedAntennaName(index);
  console.log(`Antenna ${index} selected: ${antennaNames[index]}`);
  saveAntennaData();
}

/*----------------------------------------------------------------
  4) Data Arrays for TYPE/STYLE/POL/MFG and helper functions
-----------------------------------------------------------------*/
function stripNumbering(str) {
  const dashIndex = str.indexOf("-");
  if (dashIndex >= 0) {
    return str.substring(dashIndex + 1).trim();
  }
  return str.trim();
}

function stripPolarizationNumbering(str) {
  const spaceIndex = str.indexOf(" ");
  if (spaceIndex >= 0) {
    return str.substring(spaceIndex + 1).trim();
  }
  return str.trim();
}

const antennaTypes = [
  "0 - None",
  "1 - Wire",
  "2 - Directional",
  "3 - Satellite"
];
const antennaStyles = {
  0: ["0.0 - None"],
  1: ["0.0 - None", "1.1 - Dipoles", "1.2 - End Fed", "1.3 - Random Wire", "1.4 - Quarter-Wave", "1.5 - Loop", "1.6 - Magnetic Loop"],
  2: ["0.0 - None", "2.1 - Beam", "2.2 - Yagi", "2.3 - Log-Periodic", "2.4 - Dish", "2.5 - Omni"],
  3: ["0.0 - None", "3.1 - Beam", "3.2 - Yagi", "3.3 - Helical"]
};

const antennaPols = {
  0: {
    0: ["0.0-0.0 None"]
  },
  1: {
    0: ["0.0-0.0 None"],
    1: ["1.1-1.1 Vertical", "1.1-1.2 Horizontal"],
    2: ["1.1-2.1 Vertical", "1.1-2.2 Horizontal"],
    3: ["1.1-3.1 Vertical", "1.1-3.2 Horizontal"],
    4: ["1.1-4.1 Vertical"],
    5: ["1.1-5.1 Horizontal"],
    6: ["1.1-6.1 Horizontal"]
  },
  2: {
    0: ["0.0-0.0 None"],
    1: ["0.0-0.0 None", "2.1-1.1 Vertical", "2.1-1.2 Horizontal"],
    2: ["2.2-1.1 Vertical", "2.2-1.2 Horizontal"],
    3: ["2.3-1.1 Vertical", "2.3-1.2 Horizontal"],
    4: ["2.4-1.1 Circular", "2.4-1.2 Linear"],
    5: ["2.5-1.1 Vertical"]
  },
  3: {
    0: ["0.0-0.0 None"],
    1: ["3.1-1.1 Vertical", "3.1-1.2 Horizontal"],
    2: ["3.2-1.1 Vertical", "3.2-1.2 Horizontal"],
    3: ["3.3-1.1 Vertical", "3.3-1.2 Horizontal", "3.3-1.3 Circular"]
  }
};
const antennaMfg = [
  "0 - None",
  "Chameleon",
  "Comet",
  "Cushcraft",
  "Diamond",
  "HomeBrew",
  "Hustler",
  "M2",
  "MFJ",
  "SteppIR",
  "SolarCON"
];

/*----------------------------------------------------------------
  5) updateOptionButtons => loads from antennaState + saves to localStorage
-----------------------------------------------------------------*/
function updateOptionButtons() {
  const st = antennaState[currentAntennaIndex];
  let typeStr = stripNumbering(antennaTypes[st.typeIndex]);
  let styleStr = "None";
  let polStr = "None";
  let mfgStr = stripNumbering(antennaMfg[st.mfgIndex]);
  
  if (st.typeIndex !== 0) {
    let styleArray = antennaStyles[st.typeIndex];
    if (styleArray && st.styleIndex < styleArray.length) {
      styleStr = stripNumbering(styleArray[st.styleIndex]);
    }
    if (st.styleIndex === 0) styleStr = "None";
  } else {
    typeStr = "None";
  }
  
  if (st.typeIndex !== 0 && st.styleIndex !== 0) {
    let polArray = antennaPols[st.typeIndex][st.styleIndex];
    if (polArray && st.polIndex < polArray.length) {
      polStr = stripPolarizationNumbering(polArray[st.polIndex]);
    }
  }
  
  document.getElementById("antennaTypeButton").textContent = `TYPE: ${typeStr}`;
  document.getElementById("antennaStyleButton").textContent = `STYLE: ${styleStr}`;
  document.getElementById("antennaPolButton").textContent = `POL: ${polStr}`;
  document.getElementById("antennaMfgButton").textContent = `MFG: ${mfgStr}`;
  
  saveAntennaData();
}

/*----------------------------------------------------------------
  6) positionDropdownBelowButton => narrower container => #antenna-details
-----------------------------------------------------------------*/
function positionDropdownBelowButton(dropdown, button) {
  // 1) Grab #antenna-details container
  const container = document.getElementById("antenna-details");
  const containerRect = container.getBoundingClientRect();
  const buttonRect    = button.getBoundingClientRect();

  // 2) The offset is the button's bottom minus the container's top
  const offsetTop  = (buttonRect.bottom - containerRect.top) ; // +5 gap
  const offsetLeft = (buttonRect.left   - containerRect.left) -7;

  // 3) Absolutely position inside #antenna-details
  dropdown.style.position = "absolute";
  dropdown.style.top      = offsetTop + "px";
  dropdown.style.left     = offsetLeft + "px";
  dropdown.style.display  = "block";
}

/*----------------------------------------------------------------
  7) show/hide for each dropdown => call positionDropdownBelowButton
-----------------------------------------------------------------*/
function showTypeDropdown() {
  console.log("showTypeDropdown() called...");
  const button = document.getElementById("antennaTypeButton");
  const dropdown = document.getElementById("typeDropdown");
  dropdown.innerHTML = "";

  antennaTypes.forEach((typeStr, index) => {
    const displayText = stripNumbering(typeStr);
    const btn = document.createElement("button");
    btn.textContent = displayText;
    btn.addEventListener("click", () => {
      let st = antennaState[currentAntennaIndex];
      st.typeIndex = index;
      st.styleIndex = 0;
      st.polIndex = 0;
      if (st.typeIndex === 0) st.mfgIndex = 0;
      updateOptionButtons();
      hideTypeDropdown();
    });
    dropdown.appendChild(btn);
  });

  positionDropdownBelowButton(dropdown, button);
  typeDropdownOpen = true;
}

function hideTypeDropdown() {
  console.log("hideTypeDropdown() called...");
  const dropdown = document.getElementById("typeDropdown");
  dropdown.style.display = "none";
  typeDropdownOpen = false;
}

function showStyleDropdown() {
  console.log("showStyleDropdown() called...");
  const button = document.getElementById("antennaStyleButton");
  const dropdown = document.getElementById("styleDropdown");
  dropdown.innerHTML = "";

  let st = antennaState[currentAntennaIndex];
  if (st.typeIndex === 0) return; // no styles if type=NONE
  const styleArray = antennaStyles[st.typeIndex];
  styleArray.forEach((styleStr, index) => {
    const displayText = stripNumbering(styleStr);
    const btn = document.createElement("button");
    btn.textContent = displayText;
    btn.addEventListener("click", () => {
      st.styleIndex = index;
      st.polIndex = 0;
      updateOptionButtons();
      hideStyleDropdown();
    });
    dropdown.appendChild(btn);
  });

  positionDropdownBelowButton(dropdown, button);
}

function hideStyleDropdown() {
  console.log("hideStyleDropdown() called...");
  const dropdown = document.getElementById("styleDropdown");
  dropdown.style.display = "none";
}

function showPolDropdown() {
  console.log("showPolDropdown() called...");
  const button = document.getElementById("antennaPolButton");
  const dropdown = document.getElementById("polDropdown");
  dropdown.innerHTML = "";

  let st = antennaState[currentAntennaIndex];
  if (st.typeIndex === 0 || st.styleIndex === 0) return; // no pol if type=NONE or style=NONE
  const polArray = antennaPols[st.typeIndex][st.styleIndex];
  if (!polArray) return;

  polArray.forEach((polStr, index) => {
    const displayText = stripPolarizationNumbering(polStr);
    const btn = document.createElement("button");
    btn.textContent = displayText;
    btn.addEventListener("click", () => {
      st.polIndex = index;
      updateOptionButtons();
      hidePolDropdown();
    });
    dropdown.appendChild(btn);
  });

  positionDropdownBelowButton(dropdown, button);
}

function hidePolDropdown() {
  console.log("hidePolDropdown() called...");
  const dropdown = document.getElementById("polDropdown");
  dropdown.style.display = "none";
}

function showMfgDropdown() {
  console.log("showMfgDropdown() called...");
  let st = antennaState[currentAntennaIndex];

  // If TYPE=NONE => do nothing
  if (st.typeIndex === 0) {
    console.log("TYPE is None => MFG popup canceled.");
    return;
  }

  const button = document.getElementById("antennaMfgButton");
  const dropdown = document.getElementById("mfgDropdown");
  dropdown.innerHTML = "";

  antennaMfg.forEach((mfgStr, index) => {
    const displayText = stripNumbering(mfgStr);
    const btn = document.createElement("button");
    btn.textContent = displayText;
    btn.addEventListener("click", () => {
      st.mfgIndex = index;
      updateOptionButtons();
      hideMfgDropdown();
    });
    dropdown.appendChild(btn);
  });

  positionDropdownBelowButton(dropdown, button);
}

function hideMfgDropdown() {
  console.log("hideMfgDropdown() called...");
  const dropdown = document.getElementById("mfgDropdown");
  dropdown.style.display = "none";
}

/*----------------------------------------------------------------
  8) On DOMContentLoaded, attach pointer event listeners and load localStorage
-----------------------------------------------------------------*/
window.addEventListener('DOMContentLoaded', () => {

  // Utility: Attach pointer-based long press to a button.
  // shortPressFn is called if released before 750ms is up,
  // longPressFn is called if the user holds for 750ms.
  function addLongPress(button, longPressFn, shortPressFn) {
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

  // TYPE button
  const typeButton = document.getElementById("antennaTypeButton");
  addLongPress(typeButton,
    () => { showTypeDropdown(); },
    () => {
      let st = antennaState[currentAntennaIndex];
      st.typeIndex = (st.typeIndex + 1) % antennaTypes.length;
      st.styleIndex = 0;
      st.polIndex = 0;
      if (st.typeIndex === 0) st.mfgIndex = 0;
      updateOptionButtons();
    }
  );

  // STYLE button
  const styleButton = document.getElementById("antennaStyleButton");
  addLongPress(styleButton,
    () => { showStyleDropdown(); },
    () => {
      let st = antennaState[currentAntennaIndex];
      if (st.typeIndex === 0) return; // no styles if type=NONE
      let styleArray = antennaStyles[st.typeIndex];
      st.styleIndex = (st.styleIndex + 1) % styleArray.length;
      st.polIndex = 0;
      updateOptionButtons();
    }
  );

  // POL button
  const polButton = document.getElementById("antennaPolButton");
  addLongPress(polButton,
    () => { showPolDropdown(); },
    () => {
      let st = antennaState[currentAntennaIndex];
      if (st.typeIndex === 0 || st.styleIndex === 0) return;
      let polArray = antennaPols[st.typeIndex][st.styleIndex];
      if (!polArray) return;
      st.polIndex = (st.polIndex + 1) % polArray.length;
      updateOptionButtons();
    }
  );

  // MFG button
  const mfgButton = document.getElementById("antennaMfgButton");
  addLongPress(mfgButton,
    () => { showMfgDropdown(); },
    () => {
      let st = antennaState[currentAntennaIndex];
      // If TYPE=NONE => do nothing on short press
      if (st.typeIndex === 0) {
        console.log("MFG short press canceled because TYPE is None.");
        return;
      }
      st.mfgIndex = (st.mfgIndex + 1) % antennaMfg.length;
      updateOptionButtons();
    }
  );

  // Hide dropdowns if clicking outside
  document.addEventListener("click", (e) => {
    const typeDropdown  = document.getElementById("typeDropdown");
    const styleDropdown = document.getElementById("styleDropdown");
    const polDropdown   = document.getElementById("polDropdown");
    const mfgDropdown   = document.getElementById("mfgDropdown");

    const typeButton  = document.getElementById("antennaTypeButton");
    const styleButton = document.getElementById("antennaStyleButton");
    const polButton   = document.getElementById("antennaPolButton");
    const mfgButton   = document.getElementById("antennaMfgButton");

    // TYPE
    if (typeDropdown && !typeDropdown.contains(e.target) && e.target !== typeButton) {
      typeDropdown.style.display = "none";
      typeDropdownOpen = false;
    }
    // STYLE
    if (styleDropdown && !styleDropdown.contains(e.target) && e.target !== styleButton) {
      styleDropdown.style.display = "none";
    }
    // POL
    if (polDropdown && !polDropdown.contains(e.target) && e.target !== polButton) {
      polDropdown.style.display = "none";
    }
    // MFG
    if (mfgDropdown && !mfgDropdown.contains(e.target) && e.target !== mfgButton) {
      mfgDropdown.style.display = "none";
    }
  });

  // Antenna selection buttons (existing logic)
  document.querySelectorAll('.antenna-button').forEach(button => {
    let holdTimeout = null;
    let holdFired = false;
    button.addEventListener('mousedown', () => {
      holdFired = false;
      holdTimeout = setTimeout(() => {
        button.classList.toggle('disabled');
        if (button.classList.contains('disabled')) {
          button.classList.remove('selected');
        }
        holdFired = true;
      }, 500);
    });
    button.addEventListener('mouseleave', () => {
      if (holdTimeout) {
        clearTimeout(holdTimeout);
        holdTimeout = null;
      }
    });
    button.addEventListener('mouseup', () => {
      if (holdTimeout) {
        clearTimeout(holdTimeout);
        holdTimeout = null;
        if (!button.classList.contains('disabled') && !holdFired) {
          document.querySelectorAll('.antenna-button').forEach(b => b.classList.remove('selected'));
          button.classList.add('selected');
          currentAntennaIndex = parseInt(button.dataset.index, 10);
          refreshUIForAntenna(currentAntennaIndex);
          updateOptionButtons(); 
        }
      }
    });
  });

  // LED circles
  document.querySelectorAll('.led').forEach(led => {
    led.addEventListener('click', (e) => {
      e.stopPropagation();
      if (currentAntennaIndex === null) return;
      let st = antennaState[currentAntennaIndex];
      const ledIndex = parseInt(led.getAttribute('data-index'), 10);
      st.bandPattern ^= (1 << ledIndex);
      updateLEDsFromConfig(currentAntennaIndex);
      console.log(`Antenna ${currentAntennaIndex} LED pattern: ${st.bandPattern.toString(2).padStart(16, '0')}`);
      saveAntennaData();
    });
  });

  // Tuner toggle
  function toggleTuner() {
    if (currentAntennaIndex === null) return;
    const antennaBtn = document.querySelector(`.antenna-button[data-index="${currentAntennaIndex}"]`);
    if (!antennaBtn || antennaBtn.classList.contains('disabled')) return;
    let st = antennaState[currentAntennaIndex];
    st.bandPattern ^= (1 << 14);
    updateTunerButton(currentAntennaIndex);
    console.log(`Tuner toggled for antenna ${currentAntennaIndex}, config: ${st.bandPattern.toString(2).padStart(16, '0')}`);
    saveAntennaData();
  }
  document.getElementById('btnTuner').addEventListener('click', (e) => {
    e.stopPropagation();
    toggleTuner();
  });

// 1) Load from localStorage
loadAntennaData();

// 2) Only select antenna 0 if currentAntennaIndex is still null or undefined
if (currentAntennaIndex == null) {
  document.querySelector(`.antenna-button[data-index="0"]`).classList.add('selected');
  refreshUIForAntenna(0);
  updateOptionButtons();
}
});