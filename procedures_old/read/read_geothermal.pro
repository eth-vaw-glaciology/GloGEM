PRO read_geothermal,dir,firnice_geotherm_flux

; read grid-file for geothermal heatflux
   fn=dir+'geothermal_flux.grid'
   header=strarr(6) & openr,1, fn & readf,1, header
   ncols=long(strmid(header(0),6,40)) & nrows=long(strmid(header(1),6,40))
   da=dblarr(ncols,nrows) & readf,1, da & close, 1
   xllcorner=double(strmid(header(2),10,40))
   yllcorner=double(strmid(header(3),10,40))
   cellsize=double(strmid(header(4),9,40))
   a=cellsize/2d & fit_xx=lindgen(ncols)*cellsize+xllcorner+a & fit_yy=lindgen(nrows)*cellsize+yllcorner+a
   firnice_geotherm_flux=rotate(da,7)/1000.

end
