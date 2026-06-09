; *************************************************************
; read_supraglacialdebris
;
; Read per-band supraglacial debris properties and the Ostrem-curve
; melt-reduction lookup table for an individual glacier.
;
; Reads debris thickness, coverage fraction, melt factor, and pond
; density from the glacier-specific debris data file, adjusting the
; band array dimensions if the advance scheme is active. If no debris
; file exists, all debris arrays are initialised to zero or unity
; defaults. Also reads the Ostrem-curve factor file to provide the
; debris-thickness-dependent melt-reduction factors (debris_type_th,
; debris_type_red) used in the melt calculation.
; *************************************************************

compile_opt idl2

  ; Check if supraglacial debris data should be read
  if debris_supraglacial eq 'y' then begin

    ; Construct the filename for the debris data file
    fn = dir_data + '../debris/' + region + '/debris_' + id[gg[g]] + '.dat'
    a = findfile(fn)  ; Search for the file

    ; If the file exists, read its contents
    if a[0] ne '' then begin

      anz = file_lines(fn) - 5  ; Determine the number of lines to read (excluding headers)
      s = strarr(5)  ; Initialize an array to store header lines
      da = dblarr(8, anz)  ; Initialize an 8-row array to store data

      ; Open the file for reading
      openr, 1, fn
      readf, 1, s  ; Read header lines
      readf, 1, da  ; Read data lines
      close, 1  ; Close the file

      ; If glacier advance is allowed, adjust the number of bands accordingly
      if advance eq 'y' and nb gt 3 then begin
        nb0 = nb - adv_addband  ; Calculate the adjusted number of bands
        tt = da  ; Store the original data temporarily
        da = dblarr(8, nb)  ; Initialize a new array with updated band count
        da[*, nb - nb0:nb - 1] = tt[*, 0:nb0 - 1]  ; Transfer the relevant data
      endif else adv_addband = 0  ; If no advance, set additional bands to zero

      ; Extract relevant debris properties from the data
      debris_thick = da[5, *]  ; Debris thickness
      debris_frac = da[4, *]  ; Debris coverage fraction
      debris_mf = da[6, *]  ; Melt factor reduction due to debris
      debris_ponddens = da[7, *]  ; Density of supraglacial ponds
    endif else begin
      ; If the debris file is not found, set default values (debris absent everywhere)
      debris_thick = dblarr(nb)  ; Set debris thickness to zero
      debris_frac = dblarr(nb)  ; Set debris fraction to zero
      debris_mf = dblarr(nb) + 1  ; Set melt factor to default (no reduction)
      debris_ponddens = dblarr(nb)  ; Set pond density to zero
    endelse

    debris_thick0 = debris_thick  ; Store initial debris thickness values

    ; If pond enhancement factor is zero, ensure pond density is set to zero
    if debris_pond_enhancementfactor eq 0 then debris_ponddens = dblarr(nb)

    ; Ensure no ponds exist where debris fraction is zero
    ii = where(debris_frac eq 0, ci)  ; Find locations with no debris
    if ci gt 0 then debris_ponddens[ii] = 0  ; Set pond density to zero at those locations

    ; Read the debris melt-reduction factor file (Ostrem-curve)
    fn = dir_data + '../debris/' + region + '/factor_' + id[gg[g]] + '.dat'  ; Construct filename
    anz = file_lines(fn) - 3  ; Determine number of data lines (excluding headers)
    s = strarr(3)  ; Initialize array for header lines
    da = dblarr(3, anz)  ; Initialize array to store data

    ; Open the file and read its contents
    openr, 1, fn
    readf, 1, s  ; Read header lines
    readf, 1, da  ; Read data lines
    close, 1  ; Close the file

    ; Extract debris melt-reduction properties from the data
    debris_type_th = da[1, *]  ; Thickness values for melt-reduction
    debris_type_red = da[2, *]  ; Reduction factors corresponding to thickness
  endif
