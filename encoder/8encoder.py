#!/usr/bin/env python3
# ShackMate 8-Encoder WS Server (strict OFF gating + dual-bank repaint + ON repaint window)
# Semantics:
#   - Switch OFF:  switch LED = RED; all encoder LEDs hard-off (toggle states preserved)
#   - Switch ON :  switch LED = GREEN; toggled ON -> ON color, toggled OFF -> FX/idle OFF
# Resilience:
#   - Writes LEDs to BOTH plausible banks.
#   - After switch -> ON, forces N frames of direct repaint (ignores cache) so colors return reliably.

import asyncio, json, signal, struct, time
from typing import List, Optional, Tuple, Set
from smbus2 import SMBus, i2c_msg
import websockets

# ---------- Config ----------
I2C_BUS, I2C_ADDR = 1, 0x41
WS_HOST, WS_PORT = "0.0.0.0", 4008

LOOP_HZ       = 80
BTN_EVERY     = 1
SW_EVERY      = 1
PAUSE_S       = 0.00025
BTN_GAP_S     = 0.00025

SWITCH_INVERT       = False
INVERT_BUTTONS      = True
BUTTON_DEBOUNCE_MS  = 25
LONG_PRESS_MS       = 1000
COUNTS_PER_DETENT   = 2

ON_COLOR_DEFAULT    = (0, 0, 200)   # blue
OFF_COLOR_DEFAULT   = (0, 0, 0)
ON_COLOR_SWITCH     = (0, 200, 0)   # green
OFF_COLOR_SWITCH    = (200, 0, 0)   # red

FX_HOLD_MS, FX_SWEEP_MS, FX_FADE_MS, FX_MIN_STEP_MS = 80, 300, 500, 30

# How many frames to force-direct repaint after switch goes ON
REPAINT_FRAMES_ON_SWITCH = 4   # ~50ms at 80Hz

MAX_RETRIES, BACKOFF_BASE = 3, 0.002
def _retry_sleep(a:int): time.sleep(BACKOFF_BASE*(a+1))
def log(*a): print(*a, flush=True)

# ---------- Registers ----------
REG_CNT_BASE, REG_BTN_BASE, REG_SWITCH, REG_RST_BASE = 0x00, 0x50, 0x60, 0x40
REG_LED_BANK0, REG_LED_BANK1 = 0x70, 0x80
ENCODERS, BUTTONS, SWITCH_LED_INDEX = 8, 8, 8

# ---------- I2C (STOP-only, dual-bank LED writes) ----------
class M5_8EncoderStopOnly:
    def __init__(self, bus:SMBus, addr:int):
        self.bus, self.addr = bus, addr

    def _read_stop(self, reg:int, n:int, pause_s:float=PAUSE_S)->bytes:
        last=None
        for a in range(MAX_RETRIES):
            try:
                self.bus.i2c_rdwr(i2c_msg.write(self.addr, [reg & 0xFF]))
                time.sleep(pause_s)
                r = i2c_msg.read(self.addr, n); self.bus.i2c_rdwr(r)
                return bytes(r)
            except Exception as e:
                last=e; _retry_sleep(a)
        raise last or OSError(121, "Remote I/O error")

    def _write_stop(self, reg:int, data:bytes):
        last=None; payload=bytes([reg & 0xFF]) + bytes(data)
        for a in range(MAX_RETRIES):
            try:
                self.bus.i2c_rdwr(i2c_msg.write(self.addr, payload)); return
            except Exception as e:
                last=e; _retry_sleep(a)
        raise last or OSError(121, "Remote I/O error")

    def read_all_counters(self)->List[int]:
        vals=[0]*ENCODERS
        for i in range(ENCODERS):
            b=self._read_stop(REG_CNT_BASE+4*i,4)
            vals[i]=struct.unpack("<i",b)[0]
        return vals

    def read_all_buttons_raw(self)->List[Optional[int]]:
        out=[0]*BUTTONS
        for i in range(BUTTONS):
            try: out[i]=self._read_stop(REG_BTN_BASE+i,1)[0]
            except Exception: out[i]=None
            time.sleep(BTN_GAP_S)
        return out

    def read_switch(self)->Optional[int]:
        try:
            v=self._read_stop(REG_SWITCH,1)[0]
            v=1 if v>0 else 0
            return (1-v) if SWITCH_INVERT else v
        except Exception:
            return None

    def set_led_rgb_dual(self, idx:int, r:int, g:int, b:int):
        """Write to BOTH plausible addresses for this index."""
        if not (0 <= idx <= 8): return
        r=max(0,min(255,int(r))); g=max(0,min(255,int(g))); b=max(0,min(255,int(b)))
        # bank0 0..8
        try: self._write_stop(REG_LED_BANK0 + 3*idx, bytes((r,g,b)))
        except Exception: pass
        # bank1 5..8
        if idx >= 5:
            try: self._write_stop(REG_LED_BANK1 + 3*(idx-5), bytes((r,g,b)))
            except Exception: pass

    def hard_off_all_leds(self):
        # bank0 0..8
        for idx in range(0,9):
            try: self._write_stop(REG_LED_BANK0 + 3*idx, b"\x00\x00\x00")
            except Exception: pass
        # bank1 5..8
        for idx in range(5,9):
            try: self._write_stop(REG_LED_BANK1 + 3*(idx-5), b"\x00\x00\x00")
            except Exception: pass

    def reset_counter(self, idx:int):
        if not (0 <= idx < ENCODERS): return
        try: self._write_stop(REG_RST_BASE+idx, b"\x01")
        except Exception:
            try: self._write_stop(REG_RST_BASE+idx, b"\xFF")
            except Exception: pass

# ---------- Server ----------
class EncoderWSServer:
    def __init__(self):
        self.bus=SMBus(I2C_BUS); self.dev=M5_8EncoderStopOnly(self.bus, I2C_ADDR)

        # Telemetry
        self.encoder_positions=[0]*ENCODERS
        self.button_states=[0]*BUTTONS
        self.switch_state=0
        self.device_online=True

        # Persistent LED toggle state (preserved across switch changes)
        self.led_toggled=[False]*ENCODERS

        # Colors
        self.enc_on_color=[None]*ENCODERS   # type: List[Optional[Tuple[int,int,int]]]
        self.enc_off_color=[None]*ENCODERS
        self.switch_color_on=list(ON_COLOR_SWITCH)
        self.switch_color_off=list(OFF_COLOR_SWITCH)
        self.on_color_default=list(ON_COLOR_DEFAULT)
        self.off_color_default=list(OFF_COLOR_DEFAULT)

        # Buttons
        self.prev_btn_raw=[0]*ENCODERS
        self._press_start_ms=[0.0]*ENCODERS
        self._press_long_done=[False]*ENCODERS
        self._last_press_ms=[0.0]*ENCODERS

        # Detent scaling residuals
        self._scale_residual=[0]*ENCODERS

        # FX
        self._fx_active=[False]*ENCODERS
        self._fx_dir=[0]*ENCODERS
        self._fx_start_ms=[0.0]*ENCODERS
        self._fx_last_upd_ms=[0.0]*ENCODERS

        # LED cache (what we believe is on device)
        self._last_led_rgb=[(0,0,0)]*9

        # After switch->ON, force N direct repaints
        self._repaint_frames:int = 0

        # Change detection
        self._last_cnt=self.dev.read_all_counters()
        self.prev_positions=self.encoder_positions.copy()
        self.prev_buttons=self.button_states.copy()
        self.prev_switch=self.switch_state
        self.prev_online=self.device_online

        self.clients:Set[websockets.WebSocketServerProtocol]=set()
        self._stop=asyncio.Event()

        self._apply_led_policy(initial=True)

    # ---- JSON helpers ----
    @staticmethod
    def _now_hms()->str: return time.strftime("%H:%M:%S")
    def snapshot(self)->dict:
        return {"time":self._now_hms(),"encoders":self.encoder_positions,
                "buttons":self.button_states,"switch":self.switch_state,
                "online":1 if self.device_online else 0}
    def has_changes(self)->bool:
        return (self.encoder_positions!=self.prev_positions or
                self.button_states!=self.prev_buttons or
                self.switch_state!=self.prev_switch or
                self.device_online!=self.prev_online)
    def commit_prev(self):
        self.prev_positions=self.encoder_positions.copy()
        self.prev_buttons=self.button_states.copy()
        self.prev_switch=self.switch_state
        self.prev_online=self.device_online

    # ---- math helpers ----
    @staticmethod
    def _trunc_div_with_residual(total:int, divisor:int):
        sign=1 if total>=0 else -1
        q,r=divmod(abs(total), divisor)
        return sign*q, sign*r
    @staticmethod
    def _lerp(a:float,b:float,t:float)->float:
        t=0.0 if t<0.0 else (1.0 if t>1.0 else t)
        return a+(b-a)*t
    def _gradient_color(self, sgn:int, u:float)->Tuple[int,int,int]:
        u=0.0 if u<0.0 else (1.0 if u>1.0 else u)
        if sgn>=0:
            if u<0.5: t=u*2;  r=0;                 g=int(self._lerp(0,255,t)); b=int(self._lerp(255,0,t))
            else:     t=(u-.5)*2; r=int(self._lerp(0,255,t)); g=int(self._lerp(255,0,t)); b=0
        else:
            if u<0.5: t=u*2;  r=int(self._lerp(255,0,t)); g=int(self._lerp(0,255,t)); b=0
            else:     t=(u-.5)*2; r=0;                   g=int(self._lerp(255,0,t)); b=int(self._lerp(0,255,t))
        return (r,g,b)

    # ---- LED helpers (dual-bank) ----
    def _set_led_direct(self, idx:int, rgb:Tuple[int,int,int]):
        self.dev.set_led_rgb_dual(idx, *rgb)
        if 0<=idx<=8: self._last_led_rgb[idx]=rgb
    def _set_led_cached(self, idx:int, rgb:Tuple[int,int,int]):
        if 0<=idx<=8 and self._last_led_rgb[idx]!=rgb:
            self.dev.set_led_rgb_dual(idx, *rgb)
            self._last_led_rgb[idx]=rgb
    def _clear_led_cache(self): self._last_led_rgb=[(-1,-1,-1)]*9

    # ---- main cycle ----
    def read_cycle(self, tick:int):
        now_ms=time.monotonic()*1000.0
        try:
            # 1) counters -> detents
            cnt=self.dev.read_all_counters()
            raw_inc=[c-p for c,p in zip(cnt, self._last_cnt)]
            self._last_cnt=cnt
            scaled=[0]*ENCODERS
            for i,inc in enumerate(raw_inc):
                total=self._scale_residual[i]+inc
                q,r=self._trunc_div_with_residual(total, COUNTS_PER_DETENT)
                scaled[i]=q; self._scale_residual[i]=r
            for i,d in enumerate(scaled):
                if d:
                    self.encoder_positions[i]+=d
                    if (not self.led_toggled[i]) and (self.switch_state==1):
                        self._fx_active[i]=True
                        self._fx_dir[i]= 1 if d>0 else -1
                        self._fx_start_ms[i]=now_ms
                        self._fx_last_upd_ms[i]=0.0

            # 2) buttons (short vs long)
            if tick % BTN_EVERY == 0:
                raw=self.dev.read_all_buttons_raw()
                raw=[(p if x is None else x) for x,p in zip(raw, self.prev_btn_raw)]
                inv=[0 if v else 1 for v in raw] if INVERT_BUTTONS else raw
                for i in range(ENCODERS):
                    prev=(0 if self.prev_btn_raw[i] else 1) if INVERT_BUTTONS else self.prev_btn_raw[i]
                    cur=inv[i]
                    if prev==0 and cur==1:
                        self._press_start_ms[i]=now_ms; self._press_long_done[i]=False
                    if cur==1 and not self._press_long_done[i]:
                        if (now_ms - self._press_start_ms[i]) >= LONG_PRESS_MS:
                            self.encoder_positions[i]=0; self._scale_residual[i]=0; self._last_cnt[i]=0
                            self.dev.reset_counter(i); self._fx_active[i]=False
                            self._press_long_done[i]=True
                    if prev==1 and cur==0:
                        held=now_ms - self._press_start_ms[i]
                        if not self._press_long_done[i] and held < LONG_PRESS_MS:
                            if (now_ms - self._last_press_ms[i]) >= BUTTON_DEBOUNCE_MS:
                                self.led_toggled[i]=not self.led_toggled[i]
                                self._last_press_ms[i]=now_ms
                                if self.led_toggled[i]: self._fx_active[i]=False
                        self._press_start_ms[i]=0.0; self._press_long_done[i]=False
                self.button_states=inv; self.prev_btn_raw=raw

            # 3) switch each loop
            if tick % SW_EVERY == 0:
                sw=self.dev.read_switch()
                if sw is not None and sw != self.switch_state:
                    self.switch_state=sw
                    log(f"[SW] -> {'ON' if sw else 'OFF'}")
                    self._clear_led_cache()  # repaint next apply
                    if sw==0:
                        # OFF: stop FX and blast off
                        for i in range(ENCODERS): self._fx_active[i]=False
                        self.dev.hard_off_all_leds()
                        for i in range(9): self._last_led_rgb[i]=(0,0,0)
                        self._repaint_frames = 0
                    else:
                        # ON: start a short repaint window to force LEDs back on
                        self._repaint_frames = REPAINT_FRAMES_ON_SWITCH

            # 4) LEDs
            self._apply_led_policy(now_ms)

            self.device_online=True
        except Exception as e:
            log(f"[read_cycle] {e}")
            self.device_online=False

    def _apply_led_policy(self, now_ms:Optional[float]=None, initial:bool=False):
        if now_ms is None: now_ms=time.monotonic()*1000.0

        # switch LED always reflects state
        sw_rgb = tuple(self.switch_color_on if self.switch_state==1 else self.switch_color_off)
        # write switch LED via cached path (it also gets direct during repaint window below)
        self._set_led_cached(SWITCH_LED_INDEX, sw_rgb)

        if self.switch_state==0:
            # enforce visible OFF state (preserve toggles/states)
            self.dev.hard_off_all_leds()
            for i in range(9): self._last_led_rgb[i]=(0,0,0)
            if initial: time.sleep(0.01)
            return

        # switch ON -> compute desired colors
        desired = [(0,0,0)]*9
        desired[SWITCH_LED_INDEX] = sw_rgb

        for i in range(ENCODERS):
            if self.led_toggled[i]:
                on_rgb = tuple(self.enc_on_color[i] if self.enc_on_color[i] is not None else self.on_color_default)
                self._fx_active[i]=False
                desired[i]=on_rgb
                # also write via cached path (normal steady behavior)
                self._set_led_cached(i, on_rgb)
            else:
                if self._fx_active[i]:
                    if (now_ms - self._fx_last_upd_ms[i]) >= FX_MIN_STEP_MS:
                        t = now_ms - self._fx_start_ms[i]
                        if t < FX_HOLD_MS: u, amp = 0.0, 1.0
                        else:
                            u = min(1.0, (t - FX_HOLD_MS)/max(1.0, FX_SWEEP_MS))
                            amp = max(0.0, 1.0 - (t - FX_HOLD_MS)/max(1.0, FX_FADE_MS))
                        base = self._gradient_color(self._fx_dir[i], u)
                        rgb  = (int(base[0]*amp), int(base[1]*amp), int(base[2]*amp))
                        desired[i]=rgb
                        self._set_led_cached(i, rgb); self._fx_last_upd_ms[i]=now_ms
                        if amp <= 0.0:
                            self._fx_active[i]=False
                            off_rgb = tuple(self.enc_off_color[i] if self.enc_off_color[i] is not None else self.off_color_default)
                            desired[i]=off_rgb
                            self._set_led_cached(i, off_rgb)
                    else:
                        # keep last color in desired
                        desired[i]=self._last_led_rgb[i]
                else:
                    off_rgb = tuple(self.enc_off_color[i] if self.enc_off_color[i] is not None else self.off_color_default)
                    desired[i]=off_rgb
                    self._set_led_cached(i, off_rgb)

        # During repaint window after switch->ON, force-direct write desired colors
        if self._repaint_frames > 0:
            # brief pause helps some firmwares after power-gate changes
            # (not strictly necessary, but harmless)
            # time.sleep(0.002)
            for idx in range(0, 9):
                self._set_led_direct(idx, desired[idx])
            self._repaint_frames -= 1

        if initial: time.sleep(0.01)

    # ---- WS commands ----
    async def handle_cmd(self, ws, obj:dict):
        def ok(**extra):
            log("CMD ok:", {"ok":True, **extra})
            return asyncio.create_task(ws.send(json.dumps({"ok":True, **extra})))
        def err(m:str):
            log("CMD err:", {"ok":False,"error":m})
            return asyncio.create_task(ws.send(json.dumps({"ok":False,"error":m})))

        cmd = obj.get("cmd")
        if not cmd:
            return await err("missing cmd")

        if cmd=="identify":
            idx=obj.get("idx")
            if not isinstance(idx,int) or not (0<=idx<=8): return await err("idx 0..8")
            self._set_led_direct(idx,(255,255,255)); await asyncio.sleep(1.0)
            self._set_led_direct(idx,(0,0,0))
            return await ok(cmd="identify", idx=idx)

        if cmd=="diag_off":
            self.dev.hard_off_all_leds()
            for i in range(9): self._last_led_rgb[i]=(0,0,0)
            return await ok(cmd="diag_off")

        if cmd=="set_encoder_colors":
            idx=obj.get("idx");  on=obj.get("on");  off=obj.get("off")
            if not isinstance(idx,int) or not (0<=idx<ENCODERS): return await err("idx 0..7")
            if on is not None:
                if (not isinstance(on,(list,tuple)) or len(on)!=3 or any(type(c) is not int or c<0 or c>255 for c in on)):
                    return await err("on must be [r,g,b] 0..255")
                self.enc_on_color[idx]=(int(on[0]),int(on[1]),int(on[2]))
            if off is not None:
                if (not isinstance(off,(list,tuple)) or len(off)!=3 or any(type(c) is not int or c<0 or c>255 for c in off)):
                    return await err("off must be [r,g,b] 0..255")
                self.enc_off_color[idx]=(int(off[0]),int(off[1]),int(off[2]))
            self._clear_led_cache(); self._apply_led_policy()
            # nudge repaint if switch is ON
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="set_encoder_colors", idx=idx, on=self.enc_on_color[idx], off=self.enc_off_color[idx]); await self.broadcast_snapshot(); return

        if cmd=="clear_encoder_colors":
            idx=obj.get("idx")
            if not isinstance(idx,int) or not (0<=idx<ENCODERS): return await err("idx 0..7")
            self.enc_on_color[idx]=None; self.enc_off_color[idx]=None
            self._clear_led_cache(); self._apply_led_policy()
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="clear_encoder_colors", idx=idx); await self.broadcast_snapshot(); return

        if cmd=="set_default_colors":
            on=obj.get("on"); off=obj.get("off")
            if on is not None:
                if (not isinstance(on,(list,tuple)) or len(on)!=3 or any(type(c) is not int or c<0 or c>255 for c in on)):
                    return await err("on must be [r,g,b] 0..255")
                self.on_color_default=[int(on[0]),int(on[1]),int(on[2])]
            if off is not None:
                if (not isinstance(off,(list,tuple)) or len(off)!=3 or any(type(c) is not int or c<0 or c>255 for c in off)):
                    return await err("off must be [r,g,b] 0..255")
                self.off_color_default=[int(off[0]),int(off[1]),int(off[2])]
            self._clear_led_cache(); self._apply_led_policy()
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="set_default_colors", on=self.on_color_default, off=self.off_color_default); await self.broadcast_snapshot(); return

        if cmd=="set_switch_colors":
            on=obj.get("on"); off=obj.get("off")
            if on is not None:
                if (not isinstance(on,(list,tuple)) or len(on)!=3 or any(type(c) is not int or c<0 or c>255 for c in on)):
                    return await err("on must be [r,g,b] 0..255")
                self.switch_color_on=[int(on[0]),int(on[1]),int(on[2])]
            if off is not None:
                if (not isinstance(off,(list,tuple)) or len(off)!=3 or any(type(c) is not int or c<0 or c>255 for c in off)):
                    return await err("off must be [r,g,b] 0..255")
                self.switch_color_off=[int(off[0]),int(off[1]),int(off[2])]
            self._clear_led_cache(); self._apply_led_policy()
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="set_switch_colors", on=self.switch_color_on, off=self.switch_color_off); await self.broadcast_snapshot(); return

        if cmd=="reset":
            idx=obj.get("idx")
            if not isinstance(idx,int) or not (0<=idx<ENCODERS): return await err("idx 0..7")
            self.encoder_positions[idx]=0; self._scale_residual[idx]=0; self._last_cnt[idx]=0
            self.dev.reset_counter(idx); self._fx_active[idx]=False
            await ok(cmd="reset", idx=idx); await self.broadcast_snapshot(); return

        if cmd=="reset_all":
            for i in range(ENCODERS):
                self.encoder_positions[i]=0; self._scale_residual[i]=0; self._last_cnt[i]=0
                self.dev.reset_counter(i); self._fx_active[i]=False
            await ok(cmd="reset_all"); await self.broadcast_snapshot(); return

        if cmd=="get":
            try: await ws.send(json.dumps(self.snapshot()))
            except Exception: pass
            return

        # Back-compat
        if cmd=="set_led":
            idx=obj.get("idx"); rgb=obj.get("rgb")
            if not isinstance(idx,int) or not (0<=idx<=8): return await err("idx 0..8")
            if (not isinstance(rgb,(list,tuple)) or len(rgb)!=3 or any(type(c) is not int or c<0 or c>255 for c in rgb)):
                return await err("rgb must be [r,g,b] 0..255")
            if idx==SWITCH_LED_INDEX:
                self.switch_color_on=[int(rgb[0]),int(rgb[1]),int(rgb[2])]
            else:
                self.enc_on_color[idx]=(int(rgb[0]),int(rgb[1]),int(rgb[2]))
            self._clear_led_cache(); self._apply_led_policy()
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="set_led", idx=idx, rgb=rgb); await self.broadcast_snapshot(); return

        if cmd=="clear_led":
            idx=obj.get("idx")
            if not isinstance(idx,int) or not (0<=idx<=8): return await err("idx 0..8")
            if idx==SWITCH_LED_INDEX: self.switch_color_on=list(ON_COLOR_SWITCH)
            else: self.enc_on_color[idx]=None
            self._clear_led_cache(); self._apply_led_policy()
            if self.switch_state==1: self._repaint_frames = max(self._repaint_frames, REPAINT_FRAMES_ON_SWITCH)
            await ok(cmd="clear_led", idx=idx); await self.broadcast_snapshot(); return

        return await err(f"unknown cmd '{cmd}'")

    # ---- broadcasting & loops ----
    async def broadcast_if_changed(self):
        if not self.clients or not self.has_changes(): return
        await self.broadcast_snapshot(); self.commit_prev()

    async def broadcast_snapshot(self):
        msg=json.dumps(self.snapshot()); dead=set()
        for ws in list(self.clients):
            try: await ws.send(msg)
            except Exception: dead.add(ws)
        for ws in dead: self.clients.discard(ws)

    async def data_loop(self):
        log(f"🔍 Data loop started ({LOOP_HZ} Hz)")
        period=max(0.001,1.0/LOOP_HZ); tick=0
        while not self._stop.is_set():
            self.read_cycle(tick); await self.broadcast_if_changed()
            tick+=1; await asyncio.sleep(period)

    async def ws_handler(self, websocket, path=None):
        addr=getattr(websocket,"remote_address",None)
        log(f"🔌 WS client connected: {addr}")
        self.clients.add(websocket)
        try:
            await websocket.send(json.dumps(self.snapshot()))
            async for message in websocket:
                try: obj=json.loads(message)
                except Exception:
                    try: await websocket.send(json.dumps({"ok":False,"error":"invalid JSON"}))
                    except Exception: pass
                    continue
                await self.handle_cmd(websocket, obj)
        except Exception:
            pass
        finally:
            self.clients.discard(websocket)
            log(f"🔌 WS client disconnected: {addr}")

    async def ws_server(self):
        log(f"[WS] Serving on ws://{WS_HOST}:{WS_PORT}")
        async with websockets.serve(self.ws_handler, WS_HOST, WS_PORT):
            await self._stop.wait()

    async def run(self):
        tasks=[asyncio.create_task(self.data_loop()),
               asyncio.create_task(self.ws_server())]
        try: await asyncio.gather(*tasks)
        finally:
            for t in tasks:
                if not t.done(): t.cancel()
            try: await asyncio.gather(*tasks, return_exceptions=True)
            except Exception: pass

    def stop(self): self._stop.set()
    def cleanup(self):
        try:
            self.dev.hard_off_all_leds()
            try: self.dev.set_led_rgb_dual(SWITCH_LED_INDEX,0,0,0)
            except Exception: pass
        finally:
            try: self.bus.close()
            except Exception: pass

# ---------- Entrypoint ----------
def _install_signals(srv:EncoderWSServer):
    def _h(sig,frm): log("\n🛑 Shutting down…"); srv.stop()
    signal.signal(signal.SIGINT,_h); signal.signal(signal.SIGTERM,_h)

async def _amain():
    srv=EncoderWSServer(); _install_signals(srv)
    try: await srv.run()
    finally: srv.cleanup()

if __name__=="__main__":
    print("🎛️ ShackMate 8-Encoder WS Server (repaint window) on :4008")
    print("=======================================================")
    try: asyncio.run(_amain())
    except KeyboardInterrupt: pass