// rotor.js

document.addEventListener("DOMContentLoaded", function() {
  // ---------- GLOBAL VARIABLES ----------
  let rotorAZPosition = null;
  let rotorELPosition = null;
  let targetAZ = 0;
  let targetEL = 0;
  const AZ_SPEED = 360 / 58;  // approximately 6.21°/s
  const EL_SPEED = 180 / 67;  // approximately 2.69°/s
  let lastTimestamp = null;
  
  // Keypad variables
  let keypadInput = "";
  let activeMeter = null; // "AZ" or "EL"
  let pressTimer = null;
  
  // ---------- INITIALIZATION ----------
  // Load rotor positions from localStorage; default to 0 if not set
  let storedAZ = localStorage.getItem("rotorAZPosition");
  rotorAZPosition = (storedAZ !== null && !isNaN(parseFloat(storedAZ))) ? parseFloat(storedAZ) : 0;
  let storedEL = localStorage.getItem("rotorELPosition");
  rotorELPosition = (storedEL !== null && !isNaN(parseFloat(storedEL))) ? parseFloat(storedEL) : 0;
  targetAZ = rotorAZPosition;
  targetEL = rotorELPosition;
  
  // Set stored M1–M6 button colors if values are stored
  for (let i = 1; i <= 6; i++) {
    let mAZ = localStorage.getItem(`M${i}_az`);
    let mEL = localStorage.getItem(`M${i}_el`);
    if (mAZ !== null && mEL !== null) {
      let rect = document.getElementById(`M${i}_rect`);
      if (rect) rect.setAttribute("fill", "blue");
    }
  }
  
  // Build scales for the analog meters
  buildAnalogAZ();
  buildAnalogEL();
  
  // Initial display update and start simulation loop
  updateDisplay();
  requestAnimationFrame(animate);
  
  // ---------- Keypad Setup ----------
  // Show keypad when clicking on any meter group (analog or digital)
  ["analogAZGroup", "analogELGroup", "digitalAZGroup", "digitalELGroup"].forEach(id => {
    let el = document.getElementById(id);
    if (el) {
      el.addEventListener("click", function(evt) {
        evt.stopPropagation();
        activeMeter = (id.indexOf("AZ") > -1) ? "AZ" : "EL";
        keypadInput = "";
        updateKeypadPrompt();
        updateKeypadDisplay();
        showKeypad();
      });
    }
  });
  // Close keypad if clicking outside of it
  document.getElementById("mainSvg").addEventListener("click", function(evt) {
    if(evt.target.closest("#keypadGroup") === null) hideKeypad();
  });
  
  // ---------- Toggle Buttons ----------
  // Manual/Automatic Toggle
  document.getElementById("toggle-button").addEventListener("click", function() {
    const modeToggle = document.getElementById("mode-toggle");
    const toggleRect = document.getElementById("toggle-button-rect");
    if (modeToggle.textContent.trim() === "MANUAL") {
      modeToggle.textContent = "AUTOMATIC";
      toggleRect.setAttribute("fill", "green");
    } else {
      modeToggle.textContent = "MANUAL";
      toggleRect.setAttribute("fill", "blue");
    }
    console.log("Manual/Automatic toggled =>", modeToggle.textContent);
  });
  
  // Rotors Enabled Toggle
  document.getElementById("rotors-toggle-button").addEventListener("click", function() {
    const rect = document.getElementById("rotors-toggle-rect");
    const txt  = document.getElementById("rotors-toggle-text");
    if (txt.textContent.trim() === "ROTORS ENABLED") {
      txt.textContent = "ROTORS STOPPED";
      rect.setAttribute("fill", "red");
    } else {
      txt.textContent = "ROTORS ENABLED";
      rect.setAttribute("fill", "green");
    }
    console.log("Rotors toggle =>", txt.textContent);
  });
  
  // ---------- Plot Click Handler ----------
  (function(){
    const posPlot = document.getElementById("posPlot");
    posPlot.style.cursor = "crosshair";
    posPlot.addEventListener("pointerdown", function(evt) {
      const svg = posPlot.ownerSVGElement;
      const pt = svg.createSVGPoint();
      pt.x = evt.clientX; pt.y = evt.clientY;
      const matrix = posPlot.getScreenCTM().inverse();
      const localPt = pt.matrixTransform(matrix);
      let dx = localPt.x - 100;
      let dy = localPt.y - 100;
      let r = Math.sqrt(dx*dx + dy*dy);
      if(r > 90) r = 90;
      let angleDeg = Math.atan2(dy, dx) * (180/Math.PI);
      // Compute AZ so that 0 is at North
      let az = (angleDeg + 90 + 360) % 360;
      let el = 90 - r;
      targetAZ = az;
      targetEL = el;
      console.log("Plot clicked => targetAZ=", az, "targetEL=", el);
      updateDisplay();
    });
  })();
  
  // ---------- M1–M6 Buttons ----------
  document.querySelectorAll("#m-buttons .m-button").forEach((btn) => {
    btn.style.cursor = "pointer";
    let btnID = btn.getAttribute("data-btn");
    let rect = btn.querySelector("rect");
    btn.addEventListener("pointerdown", function(evt) {
      evt.preventDefault();
      pressTimer = setTimeout(() => {
          localStorage.setItem(`${btnID}_az`, rotorAZPosition.toString());
          localStorage.setItem(`${btnID}_el`, rotorELPosition.toString());
          if (rect) rect.setAttribute("fill", "blue");
          console.log(`Stored => ${btnID} => AZ=${rotorAZPosition}, EL=${rotorELPosition}`);
      }, 500);
    });
    btn.addEventListener("pointerup", function(evt) {
      clearTimeout(pressTimer);
      let storedAZ = localStorage.getItem(`${btnID}_az`);
      let storedEL = localStorage.getItem(`${btnID}_el`);
      if (storedAZ !== null && storedEL !== null) {
        targetAZ = parseFloat(storedAZ);
        targetEL = parseFloat(storedEL);
        console.log(`Loaded => ${btnID} => AZ=${targetAZ}, EL=${targetEL}`);
        updateDisplay();
      }
    });
    btn.addEventListener("pointerleave", () => { clearTimeout(pressTimer); });
  });
  
  // ---------- Arrow Buttons ----------
  document.getElementById("btnLeftCircle").addEventListener("click", () => {
    targetAZ = (targetAZ + 1) % 360;
    console.log("AZ => +1 =>", targetAZ);
    updateDisplay();
  });
  document.getElementById("btnRightCircle").addEventListener("click", () => {
    targetAZ = (targetAZ - 1 + 360) % 360;
    console.log("AZ => -1 =>", targetAZ);
    updateDisplay();
  });
  document.getElementById("btnUpArrow").addEventListener("click", () => {
    targetEL = Math.min(targetEL + 1, 90);
    console.log("EL => +1 =>", targetEL);
    updateDisplay();
  });
  document.getElementById("btnDownArrow").addEventListener("click", () => {
    targetEL = Math.max(targetEL - 1, 0);
    console.log("EL => -1 =>", targetEL);
    updateDisplay();
  });
  
  // ---------- Long-Press on Meter Groups: Toggle Analog/Digital View ----------
  (function(){
    const longClickThreshold = 500;
    let pressTimer = null;
    const analogAZ = document.getElementById("analogAZGroup");
    const digitalAZ = document.getElementById("digitalAZGroup");
    const analogEL = document.getElementById("analogELGroup");
    const digitalEL = document.getElementById("digitalELGroup");
    if (!analogAZ || !digitalAZ || !analogEL || !digitalEL) return;
    function toggleMeters(){
      if (analogAZ.style.display === "none") {
        analogAZ.style.display = "block";
        digitalAZ.style.display = "none";
        analogEL.style.display = "block";
        digitalEL.style.display = "none";
      } else {
        analogAZ.style.display = "none";
        digitalAZ.style.display = "block";
        analogEL.style.display = "none";
        digitalEL.style.display = "block";
      }
      console.log("Meters toggled =>", (analogAZ.style.display === "none") ? "Digital" : "Analog");
    }
    [analogAZ, digitalAZ, analogEL, digitalEL].forEach((g) => {
      g.style.cursor = "pointer";
      g.addEventListener("pointerdown", (evt) => {
        evt.preventDefault();
        pressTimer = setTimeout(toggleMeters, longClickThreshold);
      });
      g.addEventListener("pointerup", () => { clearTimeout(pressTimer); });
      g.addEventListener("pointerleave", () => { clearTimeout(pressTimer); });
    });
  })();
  
  // ---------- Build Analog AZ Scale ----------
  function buildAnalogAZ() {
    const P0 = { x:50, y:300 }, P1 = { x:300, y:100 }, P2 = { x:550, y:300 };
    function headingToT(h){ return h / 450; }
    function bezierPoint(t, A, B, C) {
      const mt = 1 - t;
      return {
        x: mt*mt*A.x + 2*mt*t*B.x + t*t*C.x,
        y: mt*mt*A.y + 2*mt*t*B.y + t*t*C.y
      };
    }
    function bezierTangent(t, A, B, C) {
      const mt = 1 - t;
      return {
        x: 2*mt*(B.x - A.x) + 2*t*(C.x - B.x),
        y: 2*mt*(B.y - A.y) + 2*t*(C.y - B.y)
      };
    }
    const midPt = bezierPoint(0.5, P0, P1, P2);
    function inwardNormal(t) {
      const pt = bezierPoint(t, P0, P1, P2);
      const tan = bezierTangent(t, P0, P1, P2);
      let nx = -tan.y, ny = tan.x;
      const len = Math.sqrt(nx*nx + ny*ny);
      nx /= len; ny /= len;
      const toMidX = midPt.x - pt.x, toMidY = midPt.y - pt.y;
      if (nx*toMidX + ny*toMidY < 0) { nx = -nx; ny = -ny; }
      return { x: nx, y: ny };
    }
    const TICKS = document.getElementById("azTicks");
    const LABELS = document.getElementById("azLabels");
    const PTR = document.getElementById("azPointer");
    if (!TICKS || !LABELS || !PTR) return;
    const midHeads = [45, 135, 225, 315, 405];
    function barCategory(h) {
      if (h % 90 === 0) return "wide";
      if (midHeads.includes(h)) return "mid";
      return "narrow";
    }
    function barLength(cat) { return cat === "wide" ? 50 : 25; }
    function headingLabel(h) {
      if (h === 360) return "0°";
      if (h === 450) return "90°";
      return h + "°";
    }
    function setTickStyle(line, cat) {
      line.setAttribute("stroke", "white");
      line.setAttribute("stroke-width", (cat === "wide" || cat === "mid") ? "4" : "2");
    }
    for (let h = 0; h <= 450; h += 15) {
      const cat = barCategory(h);
      const t = headingToT(h);
      const pt = bezierPoint(t, P0, P1, P2);
      const normalUp = inwardNormal(t);
      const length = barLength(cat);
      const x2 = pt.x + length * normalUp.x;
      const y2 = pt.y + length * normalUp.y;
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", pt.x);
      line.setAttribute("y1", pt.y);
      line.setAttribute("x2", x2);
      line.setAttribute("y2", y2);
      setTickStyle(line, cat);
      TICKS.appendChild(line);
      if (cat === "wide") {
        const labelDist = length + 15;
        const lx = pt.x + labelDist * normalUp.x;
        const ly = pt.y + labelDist * normalUp.y;
        const txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
        txt.setAttribute("x", lx);
        txt.setAttribute("y", ly);
        txt.setAttribute("fill", "white");
        txt.setAttribute("font-size", "16");
        txt.setAttribute("font-weight", "bold");
        txt.setAttribute("text-anchor", "middle");
        txt.setAttribute("dominant-baseline", "middle");
        txt.textContent = headingLabel(h);
        LABELS.appendChild(txt);
      }
    }
    // Red pointer line for AZ
    const pointerLine = document.createElementNS("http://www.w3.org/2000/svg", "line");
    pointerLine.setAttribute("id", "azPointerLine");
    pointerLine.setAttribute("x1", "300");
    pointerLine.setAttribute("y1", "420");
    pointerLine.setAttribute("x2", "300");
    pointerLine.setAttribute("y2", "420");
    pointerLine.setAttribute("stroke", "red");
    pointerLine.setAttribute("stroke-width", "3");
    pointerLine.setAttribute("stroke-linecap", "round");
    PTR.appendChild(pointerLine);
  }
  
  // ---------- Build Analog EL Scale ----------
  function buildAnalogEL() {
    const P0 = { x:50, y:300 }, P1 = { x:300, y:100 }, P2 = { x:550, y:300 };
    function headingToT_el(h){ return h / 180; }
    function bezierPoint_el(t, A, B, C) {
      const mt = 1 - t;
      return {
        x: mt*mt*A.x + 2*mt*t*B.x + t*t*C.x,
        y: mt*mt*A.y + 2*mt*t*B.y + t*t*C.y
      };
    }
    function bezierTangent_el(t, A, B, C) {
      const mt = 1 - t;
      return {
        x: 2*mt*(B.x - A.x) + 2*t*(C.x - B.x),
        y: 2*mt*(B.y - A.y) + 2*t*(C.y - B.y)
      };
    }
    const midPt_el = bezierPoint_el(0.5, P0, P1, P2);
    function inwardNormal_el(t){
      const pt = bezierPoint_el(t, P0, P1, P2);
      const tan = bezierTangent_el(t, P0, P1, P2);
      let nx = -tan.y, ny = tan.x;
      const len = Math.sqrt(nx*nx + ny*ny);
      nx /= len; ny /= len;
      const toMidX = midPt_el.x - pt.x, toMidY = midPt_el.y - pt.y;
      if (nx*toMidX + ny*toMidY < 0) { nx = -nx; ny = -ny; }
      return { x: nx, y: ny };
    }
    const TICKS_EL = document.getElementById("elTicks");
    const LABELS_EL = document.getElementById("elLabels");
    const PTR_EL = document.getElementById("elPointer");
    if (!TICKS_EL || !LABELS_EL || !PTR_EL) return;
    function isMajorTick_el(h){ return Math.abs(h % 22.5) < 1e-9; }
    function shouldLabel_el(h){ return Math.abs(h % 45) < 1e-9; }
    function tickLength_el(isMajor){ return isMajor ? 50 : 25; }
    function setTickStyle_el(line, isMajor){
      line.setAttribute("stroke", "white");
      line.setAttribute("stroke-width", isMajor ? "4" : "2");
    }
    function headingLabel_el(h){ return h + "°"; }
    for (let h = 0; h <= 180; h += 7.5) {
      const t = headingToT_el(h);
      const pt = bezierPoint_el(t, P0, P1, P2);
      const normalUp = inwardNormal_el(t);
      const major = isMajorTick_el(h);
      const len = tickLength_el(major);
      const x2 = pt.x + len * normalUp.x;
      const y2 = pt.y + len * normalUp.y;
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", pt.x);
      line.setAttribute("y1", pt.y);
      line.setAttribute("x2", x2);
      line.setAttribute("y2", y2);
      setTickStyle_el(line, major);
      TICKS_EL.appendChild(line);
      if (shouldLabel_el(h)) {
        const labelDist = len + 15;
        const lx = pt.x + labelDist * normalUp.x;
        const ly = pt.y + labelDist * normalUp.y;
        const txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
        txt.setAttribute("x", lx);
        txt.setAttribute("y", ly);
        txt.setAttribute("fill", "white");
        txt.setAttribute("font-size", "16");
        txt.setAttribute("font-weight", "bold");
        txt.setAttribute("text-anchor", "middle");
        txt.setAttribute("dominant-baseline", "middle");
        txt.textContent = headingLabel_el(h);
        LABELS_EL.appendChild(txt);
      }
    }
    // Red pointer line for EL
    const pointerLine_el = document.createElementNS("http://www.w3.org/2000/svg", "line");
    pointerLine_el.setAttribute("id", "elPointerLine");
    pointerLine_el.setAttribute("x1", "300");
    pointerLine_el.setAttribute("y1", "420");
    pointerLine_el.setAttribute("x2", "300");
    pointerLine_el.setAttribute("y2", "420");
    pointerLine_el.setAttribute("stroke", "red");
    pointerLine_el.setAttribute("stroke-width", "3");
    pointerLine_el.setAttribute("stroke-linecap", "round");
    PTR_EL.appendChild(pointerLine_el);
  }
  
  // ---------- Check if AUTOMATIC Mode ----------
  function isAutomaticMode() {
    const modeToggle = document.getElementById("mode-toggle");
    if (!modeToggle) return false;
    return (modeToggle.textContent.trim() === "AUTOMATIC");
  }
  
  // ---------- Keypad Functions ----------
  function showKeypad() { keypadGroup.style.display = "block"; }
  function hideKeypad() { keypadGroup.style.display = "none"; }
  function updateKeypadDisplay() { keypadDisplay.textContent = keypadInput; }
  function updateKeypadPrompt() {
    if (activeMeter === "AZ") {
      keypadPrompt.textContent = "Enter AZ Value:";
    } else if (activeMeter === "EL") {
      keypadPrompt.textContent = "Enter EL Value:";
    } else {
      keypadPrompt.textContent = "";
    }
  }
  
  document.querySelectorAll(".keypad-btn").forEach(function(btn) {
    btn.addEventListener("click", function(evt) {
      evt.stopPropagation();
      const val = btn.getAttribute("data-value");
      if (val === "CLEAR") {
        keypadInput = "";
      } else if (val === "ENTER") {
        if (activeMeter === "AZ") {
          let newVal = parseInt(keypadInput);
          if (!isNaN(newVal)) targetAZ = newVal % 360;
        } else if (activeMeter === "EL") {
          let newVal = parseInt(keypadInput);
          if (!isNaN(newVal)) targetEL = Math.min(Math.max(newVal, 0), 90);
        }
        hideKeypad();
      } else {
        keypadInput += val;
      }
      updateKeypadDisplay();
    });
  });
  document.getElementById("mainSvg").addEventListener("click", function(evt) {
    if(evt.target.closest("#keypadGroup") === null) hideKeypad();
  });
  
  // ---------- Update Display Function ----------
  function updateDisplay() {
    let rAZ = Math.round(rotorAZPosition);
    let rEL = Math.round(rotorELPosition);
    updateAzPointerLine(rotorAZPosition);
    updateElPointerLine(rotorELPosition);
    let rotorAZBigDigital = document.getElementById("rotorAZBigDigital");
    if (rotorAZBigDigital) rotorAZBigDigital.textContent = ("000" + rAZ).slice(-3);
    let rotorELBigDigital = document.getElementById("rotorELBigDigital");
    if (rotorELBigDigital) rotorELBigDigital.textContent = ("000" + rEL).slice(-3);
    let tAAnalog = document.getElementById("targetAZDisplayAnalog");
    if (tAAnalog) tAAnalog.textContent = Math.round(targetAZ);
    let tADigital = document.getElementById("targetAZDisplayDigital");
    if (tADigital) tADigital.textContent = Math.round(targetAZ);
    let tEAnalog = document.getElementById("targetELDisplayAnalog");
    if (tEAnalog) tEAnalog.textContent = Math.round(targetEL);
    let tEDigital = document.getElementById("targetELDisplayDigital");
    if (tEDigital) tEDigital.textContent = Math.round(targetEL);
    
    // Update plot indicators (center at (100,100))
    let rTarget = 90 - targetEL;
    if (rTarget < 0) rTarget = 0; if (rTarget > 90) rTarget = 90;
    let angleTarget = (targetAZ - 90) * Math.PI / 180;
    let tx = 100 + rTarget * Math.cos(angleTarget);
    let ty = 100 + rTarget * Math.sin(angleTarget);
    let targetIndicator = document.getElementById("targetIndicator");
    if (targetIndicator) targetIndicator.setAttribute("transform", `translate(${tx},${ty})`);
    
    let rRotor = 90 - rotorELPosition;
    if (rRotor < 0) rRotor = 0; if (rRotor > 90) rRotor = 90;
    let angleRotor = (rotorAZPosition - 90) * Math.PI / 180;
    let rx = 100 + rRotor * Math.cos(angleRotor);
    let ry = 100 + rRotor * Math.sin(angleRotor);
    let rotorIndicator = document.getElementById("rotorIndicator");
    if (rotorIndicator) {
      rotorIndicator.setAttribute("cx", rx);
      rotorIndicator.setAttribute("cy", ry);
    }
    localStorage.setItem("rotorAZPosition", rotorAZPosition.toString());
    localStorage.setItem("rotorELPosition", rotorELPosition.toString());
  }
  
  // ---------- Update Pointer Lines (AZ & EL) ----------
  function updateAzPointerLine(rotAZ) {
    const t = rotAZ / 450;
    const P0 = { x:50, y:300 }, P1 = { x:300, y:100 }, P2 = { x:550, y:300 };
    function bezierPoint(tt, A, B, C) {
      const mt = 1-tt;
      return {
        x: mt*mt*A.x + 2*mt*tt*B.x + tt*tt*C.x,
        y: mt*mt*A.y + 2*mt*tt*B.y + tt*tt*C.y
      };
    }
    let line = document.getElementById("azPointerLine");
    if (!line) return;
    const end = bezierPoint(t, P0, P1, P2);
    line.setAttribute("x2", end.x);
    line.setAttribute("y2", end.y);
  }
  
  function updateElPointerLine(rotEL) {
    let t;
    if (rotEL >= 0) {
      t = (rotEL / 90) * 0.5;
    } else {
      t = 0.5 + ((0 - rotEL) / 180) * 0.5;
    }
    if (t < 0) t = 0; if (t > 1) t = 1;
    const P0 = { x:50, y:300 }, P1 = { x:300, y:100 }, P2 = { x:550, y:300 };
    function bezierPoint_el(tt, A, B, C) {
      const mt = 1-tt;
      return {
        x: mt*mt*A.x + 2*mt*tt*B.x + tt*tt*C.x,
        y: mt*mt*A.y + 2*mt*tt*B.y + tt*tt*C.y
      };
    }
    let line = document.getElementById("elPointerLine");
    if (!line) return;
    const end = bezierPoint_el(t, P0, P1, P2);
    line.setAttribute("x2", end.x);
    line.setAttribute("y2", end.y);
  }
  
  // ---------- Simulation Loop ----------
  function animate(timestamp) {
    if (!lastTimestamp) lastTimestamp = timestamp;
    let dt = (timestamp - lastTimestamp) / 1000;
    lastTimestamp = timestamp;
    let azDiff = targetAZ - rotorAZPosition;
    let elDiff = targetEL - rotorELPosition;
    if (isAutomaticMode()) {
      if (Math.abs(azDiff) > 1) {
        let dir = (azDiff > 0) ? 1 : -1;
        rotorAZPosition += dir * AZ_SPEED * dt;
        rotorAZPosition = Math.min(Math.max(rotorAZPosition, 0), 450);
      }
      if (Math.abs(elDiff) > 1) {
        let dir = (elDiff > 0) ? 1 : -1;
        rotorELPosition += dir * EL_SPEED * dt;
        rotorELPosition = Math.min(Math.max(rotorELPosition, -180), 90);
      }
      if (Math.abs(azDiff) < 1) rotorAZPosition = targetAZ;
      if (Math.abs(elDiff) < 1) rotorELPosition = targetEL;
    }
    let azMoving = (isAutomaticMode() && Math.abs(azDiff) > 1);
    let azEllipse = document.getElementById("azMeterEllipse");
    let azEllipseDig = document.getElementById("azMeterEllipseDigital");
    if (azEllipse) azEllipse.setAttribute("fill", azMoving ? "red" : "green");
    if (azEllipseDig) azEllipseDig.setAttribute("fill", azMoving ? "red" : "green");
    let elMoving = (isAutomaticMode() && Math.abs(elDiff) > 1);
    let elEllipse = document.getElementById("elMeterEllipse");
    let elEllipseDig = document.getElementById("elMeterEllipseDigital");
    if (elEllipse) elEllipse.setAttribute("fill", elMoving ? "red" : "green");
    if (elEllipseDig) elEllipseDig.setAttribute("fill", elMoving ? "red" : "green");
    updateDisplay();
    requestAnimationFrame(animate);
  }
  requestAnimationFrame(animate);
});