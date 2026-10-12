; *************************************************************
; firnice_perm_depth
;
; Firn-ice transition depth per band from the two-stage Herron-Langway
; (1980) densification model: where density first reaches 830 kg/m3 and
; pores close. Read in firnice_temperature_model.pro to set perm_limit.
;
; Reads hl_mask[nb] (bands to compute), hl_acc[nb] (mean annual net
; accumulation, m w.e.), hl_tk[nb] (mean annual temperature, K) and the
; HL_* constants from initialise_firnicetemp_spinup.pro.
; Sets firnice_perm_depth for the masked bands, bounded to 10-120 m.
; *************************************************************

for i = 0, nb-1 do begin
    if not hl_mask[i] then continue
    acc_hl = hl_acc[i] > 0.1d   ; floor: at least nominal firn for firn bands

    if firnice_hl1980 eq 'y' then begin
        ; Herron & Langway (1980): the 550 kg/m3 depth does not depend on A; stage 2 scales as sqrt(A)
        k0_hl  = HL80_k0 * exp(-HL80_E0 / (HL80_R * hl_tk[i]))
        k1_hl  = HL80_k1 * exp(-HL80_E1 / (HL80_R * hl_tk[i]))
        z55_hl = (HL80_g55 - HL80_g0) / (HL80_rhoi * k0_hl)
        firnice_perm_depth[i] = (z55_hl + sqrt(acc_hl) * (HL80_g83 - HL80_g55) / (HL80_rhoi * k1_hl)) > 10.d < 120.d
    endif else begin
        ; Stage 1 (400 -> 550 kg/m3): H_s1 = b / (k1 exp(-E1/(R T))), ice-equivalent metres
        H_s1  = acc_hl / (HL_k1 * exp(-HL_E1 / (HL_R * hl_tk[i])))
        z_s1  = H_s1 * HL_ln1 * (917.d/475.d)

        ; Stage 2 (550 -> 830 kg/m3): rate scales as b^0.5
        H_s2  = sqrt(acc_hl) / (HL_k2 * exp(-HL_E2 / (HL_R * hl_tk[i])))
        z_s2  = H_s2 * HL_ln2 * (917.d/690.d)

        firnice_perm_depth[i] = (z_s1 + z_s2) > 10.d < 120.d
    endelse
endfor
