; *************************************************************
; apply_calibration_params
;
; Apply calibration parameters to the current glacier.
;
; Looks up the closest matching glacier in the calibration array
; and assigns DDF, c_prec and t_offset values. If gridded
; T-offsets are enabled, t_offset is overridden with the
; spatially distributed value.
; *************************************************************

compile_opt idl2

if read_parameters eq 'y' and cal1 eq 0 then begin
   a=min(abs(double(id[gg[g]])-cali_id),ind)
   ; no row for this glacier: the nearest ID's parameters are used -- say so
   if a ne 0 then begin
      n_cali_nomatch=n_cali_nomatch+1
      print,'WARNING: glacier '+strtrim(id[gg[g]],2)+' has no row in the calibration file -- using the parameters of glacier '+string(cali_id[ind],fo='(i05)')
   endif
   case meltmodel of
      '1': begin
         DDFice=cali_ddfice[ind] & DDFsnow=cali_ddfsnow[ind] & C_prec=cali_cprec[ind]
         t_offset=cali_toff[ind]
      end
      '3': begin
         C0=cali_c0[ind] & C1=cali_c1[ind] & alb_ice=cali_a_ice[ind] & alb_snow=cali_a_snow[ind]
         C_prec=cali_cprec[ind] & t_offset=cali_toff[ind]
      end
   endcase
endif

if toff_grid eq 'y' and calibrate eq 'y' and calibration_phase ne '3' then begin
   a=min(abs(double(id[gg[g]])-cali_id_toff),ind)
   t_offset=toff_data[ind]
endif
