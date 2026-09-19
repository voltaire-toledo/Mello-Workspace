#Requires AutoHotkey v2.0

; ╭──────────────────────────────────────────────────────────────╮
; │ SoundSwap-Com.ahk — Windows Core Audio COM wrappers           │
; │ Enumeration, default-device switching, volume read.           │
; │ Native COM only — no shell-out to nircmd/SoundVolumeView.     │
; ╰──────────────────────────────────────────────────────────────╯

; --- Well-known CLSIDs / IIDs (all documented in MMDeviceapi.h except IPolicyConfig) ---
class SWAP_Guid {
  static CLSID_MMDeviceEnumerator  := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
  static IID_IMMDeviceEnumerator   := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
  static IID_IMMDeviceCollection   := "{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}"
  static IID_IMMDevice             := "{D666063F-1587-4E43-81F1-B948E807363F}"
  static IID_IPropertyStore        := "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}"
  static IID_IAudioEndpointVolume  := "{5CDF2C82-841E-4546-9722-0CF74078229A}"
  static PKEY_Device_FriendlyName  := ["{A45C254E-DF1C-4EFD-8020-67D146A850E0}", 14]
  static PKEY_AudioEndpoint_FormFactor := ["{1DA5D803-D492-4EDD-8C23-E0C0FFEE7F0E}", 0]
  ; UNDOCUMENTED — IPolicyConfig, used by every third-party sound-switcher (incl. the app we
  ; deliberately don't compete with) to set the default endpoint. There is no public Win32 API
  ; for this. This GUID pair is the Windows 10/11 variant; Vista/7 used a different interface
  ; entirely ({294935CE-...}/{568B9108-...}). Per ADR-0003, SoundSwap targets Windows 11 only —
  ; no version branching. If this breaks on a future Windows build, start here.
  static CLSID_PolicyConfigClient  := "{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}"
  static IID_IPolicyConfig         := "{F8679F50-850A-41CF-9C72-430F290290C8}"
}

; eDataFlow
SWAP_eRender := 0
SWAP_eCapture := 1
; ERole
SWAP_eConsole := 0
SWAP_eMultimedia := 1
SWAP_eCommunications := 2
; DEVICE_STATE_ACTIVE
SWAP_DEVICE_STATE_ACTIVE := 0x1

; FormFactor enum (subset — EndpointFormFactor in mmdeviceapi.h) mapped to a coarse icon key.
; ADR-0002: FormFactor is the sole classification source. Unknown/unmapped -> "generic".
SWAP_FormFactorIconKey(formFactor) {
  ; NOTE: local var deliberately not named "map" — collides (case-insensitively) with the
  ; built-in Map class, throwing "This static variable has not been assigned a value" on
  ; every call (same class-name-collision pitfall as the "enumerator" var fixed elsewhere
  ; in this file — see SWAP_EnumDevices/SWAP_GetDeviceById).
  static ffMap := Map(
    0, "speakers",       ; RemoteNetworkDevice — treated generic below, overridden per-kind by caller
    1, "speakers",        ; Speakers
    2, "headphones",       ; LineLevel (treated as generic; rarely surfaced to users)
    3, "headphones",       ; Headphones
    4, "microphone",       ; Microphone
    5, "headphones",       ; Headset
    6, "speakers",         ; Handset
    8, "digital",          ; SPDIF
    9, "digital"           ; DigitalAudioDisplayDevice (HDMI)
  )
  return ffMap.Has(formFactor) ? ffMap[formFactor] : "generic"
}

; Returns true if the Windows Audio service is running (Audiosrv). COM calls against a stopped
; service fail; check this first so failures can be told apart from "no devices."
SWAP_IsAudioServiceRunning() {
  hSCM := DllCall("advapi32\OpenSCManager", "ptr", 0, "ptr", 0, "uint", 0x0001, "ptr") ; SC_MANAGER_CONNECT
  if !hSCM
    return false
  hSvc := DllCall("advapi32\OpenServiceW", "ptr", hSCM, "wstr", "Audiosrv", "uint", 0x0004, "ptr") ; SERVICE_QUERY_STATUS
  if !hSvc {
    DllCall("advapi32\CloseServiceHandle", "ptr", hSCM)
    return false
  }
  status := Buffer(36, 0)
  ok := DllCall("advapi32\QueryServiceStatus", "ptr", hSvc, "ptr", status)
  running := ok && (NumGet(status, 4, "uint") = 4) ; SERVICE_RUNNING
  DllCall("advapi32\CloseServiceHandle", "ptr", hSvc)
  DllCall("advapi32\CloseServiceHandle", "ptr", hSCM)
  return !!running
}

; Enumerates active devices for a given kind ("Output" -> eRender, "Input" -> eCapture).
; Returns an array of {id, name, formFactor, iconKey}, sorted alphabetically by name (Q1).
SWAP_EnumDevices(kind) {
  devices := []
  if !SWAP_IsAudioServiceRunning()
    return devices

  dataFlow := (kind = "Output") ? SWAP_eRender : SWAP_eCapture

  try {
    ; NOTE: local var deliberately not named "enumerator" — that collides (case-insensitively)
    ; with the built-in Enumerator class and throws "This Class cannot be used as an output
    ; variable" at the ComCall below, silently swallowed by this function's own try/catch —
    ; which is exactly why enumeration was returning zero devices with no visible error.
    devEnum := ComObject(SWAP_Guid.CLSID_MMDeviceEnumerator, SWAP_Guid.IID_IMMDeviceEnumerator)
    ; IMMDeviceEnumerator::EnumAudioEndpoints (vtable slot 3)
    pCollection := 0
    hr := ComCall(3, devEnum, "int", dataFlow, "uint", SWAP_DEVICE_STATE_ACTIVE, "ptr*", &pCollection)
    if (hr != 0) || !pCollection
      return devices
    collection := ComValue(13, pCollection) ; VT_UNKNOWN wrapper

    count := 0
    ComCall(3, collection, "uint*", &count) ; IMMDeviceCollection::GetCount

    Loop count {
      pDevice := 0
      ComCall(4, collection, "uint", A_Index - 1, "ptr*", &pDevice) ; ::Item
      if !pDevice
        continue
      device := ComValue(13, pDevice)

      id := SWAP_GetDeviceId(device)
      name := SWAP_GetFriendlyName(device)
      formFactor := SWAP_GetFormFactor(device)
      iconKey := SWAP_FormFactorIconKey(formFactor)
      if (kind = "Input") && (iconKey = "speakers")
        iconKey := "microphone" ; input-role devices never render as "speakers"

      devices.Push({ id: id, name: name, formFactor: formFactor, iconKey: iconKey })
    }
  } catch as err {
    ; Audio service present but enumeration failed mid-way (driver hiccup) — degrade to empty,
    ; not a crash. Caller treats an empty list the same as "no devices."
    return []
  }

  ; Q1: alphabetical by friendly name.
  devices := SWAP_SortByName(devices)
  return devices
}

SWAP_SortByName(devices) {
  n := devices.Length
  Loop n - 1 {
    i := A_Index
    Loop n - i {
      j := A_Index
      if (StrCompare(devices[j].name, devices[j+1].name) > 0) {
        tmp := devices[j]
        devices[j] := devices[j+1]
        devices[j+1] := tmp
      }
    }
  }
  return devices
}

SWAP_GetDeviceId(device) {
  pId := 0
  ComCall(5, device, "ptr*", &pId) ; IMMDevice::GetId
  id := StrGet(pId, "UTF-16")
  DllCall("ole32\CoTaskMemFree", "ptr", pId)
  return id
}

SWAP_OpenPropertyStore(device) {
  pStore := 0
  ComCall(4, device, "uint", 0, "ptr*", &pStore) ; IMMDevice::OpenPropertyStore(STGM_READ)
  return pStore ? ComValue(13, pStore) : ""
}

SWAP_GetFriendlyName(device) {
  store := SWAP_OpenPropertyStore(device)
  if !store
    return "(unknown device)"
  pv := Buffer(24, 0) ; PROPVARIANT
  key := SWAP_Guid.PKEY_Device_FriendlyName
  ComCall(5, store, "ptr", SWAP_PropKeyBuf(key[1], key[2]), "ptr", pv) ; IPropertyStore::GetValue
  vt := NumGet(pv, 0, "ushort")
  name := (vt = 31) ? StrGet(NumGet(pv, 8, "ptr"), "UTF-16") : "(unknown device)" ; VT_LPWSTR
  DllCall("ole32\PropVariantClear", "ptr", pv)
  return name
}

SWAP_GetFormFactor(device) {
  store := SWAP_OpenPropertyStore(device)
  if !store
    return -1
  pv := Buffer(24, 0)
  key := SWAP_Guid.PKEY_AudioEndpoint_FormFactor
  ComCall(5, store, "ptr", SWAP_PropKeyBuf(key[1], key[2]), "ptr", pv)
  vt := NumGet(pv, 0, "ushort")
  formFactor := (vt = 19) ? NumGet(pv, 8, "uint") : -1 ; VT_UI4
  DllCall("ole32\PropVariantClear", "ptr", pv)
  return formFactor
}

; Builds a PROPERTYKEY struct {GUID fmtid; DWORD pid} in memory for a PKEY_* constant.
SWAP_PropKeyBuf(guidStr, pid) {
  buf := Buffer(20, 0)
  DllCall("ole32\CLSIDFromString", "wstr", guidStr, "ptr", buf)
  NumPut("uint", pid, buf, 16)
  return buf
}

; Reads the master volume (0.0–1.0) for a device by ID. For OSD display only, not control.
SWAP_GetVolumeScalar(deviceId) {
  try {
    device := SWAP_GetDeviceById(deviceId)
    if !device
      return 0.0
    pEndpointVolume := 0
    ; IMMDevice::Activate(IID_IAudioEndpointVolume, CLSCTX_ALL, NULL, &ppInterface)
    hr := ComCall(3, device, "ptr", SWAP_IidBuf(SWAP_Guid.IID_IAudioEndpointVolume), "uint", 0x17, "ptr", 0, "ptr*", &pEndpointVolume)
    if (hr != 0) || !pEndpointVolume
      return 0.0
    endpointVolume := ComValue(13, pEndpointVolume)
    level := 0.0
    ComCall(9, endpointVolume, "float*", &level) ; IAudioEndpointVolume::GetMasterVolumeLevelScalar
    return level
  } catch {
    return 0.0
  }
}

SWAP_IidBuf(guidStr) {
  buf := Buffer(16, 0)
  DllCall("ole32\CLSIDFromString", "wstr", guidStr, "ptr", buf)
  return buf
}

SWAP_GetDeviceById(deviceId) {
  devEnum := ComObject(SWAP_Guid.CLSID_MMDeviceEnumerator, SWAP_Guid.IID_IMMDeviceEnumerator)
  pDevice := 0
  hr := ComCall(5, devEnum, "wstr", deviceId, "ptr*", &pDevice) ; IMMDeviceEnumerator::GetDevice
  return (hr = 0 && pDevice) ? ComValue(13, pDevice) : ""
}

; Switches the default device for all three roles (console/multimedia/communications) so the
; switch is respected everywhere — every third-party sound-switcher does the same.
; Returns true on success, false on failure (caller treats false as "skip, don't hang").
SWAP_SetDefaultDevice(deviceId) {
  try {
    policyConfig := ComObject(SWAP_Guid.CLSID_PolicyConfigClient, SWAP_Guid.IID_IPolicyConfig)
    ; IPolicyConfig::SetDefaultEndpoint(LPCWSTR wszDeviceId, ERole eRole) — vtable slot 10 on the
    ; Windows 10/11 IPolicyConfig layout (undocumented; NOT the same slot as the Vista interface).
    ; VERIFY THIS OFFSET on a real machine before relying on it — see ADR-0001/ADR-0003 and the
    ; task-17 architecture note: this is the single highest fragility point in the whole plugin.
    ok := true
    for role in [SWAP_eConsole, SWAP_eMultimedia, SWAP_eCommunications] {
      hr := ComCall(10, policyConfig, "wstr", deviceId, "int", role)
      if (hr != 0)
        ok := false
    }
    return ok
  } catch {
    return false
  }
}
