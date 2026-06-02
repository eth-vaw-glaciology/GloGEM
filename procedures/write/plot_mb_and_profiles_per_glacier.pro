; *****************************************************************************
; *  Plot mass balance and profiles for each glacier *
; *****************************************************************************
; This procedure creates multiple plots for each glacier, including the elevation profile, 
; the mass balance time series, and the elevation distribution. 
; The plots are saved in the output directory for each glacier. The procedure is called at the end 
; of the main loop for each glacier, and it uses the results of the calculations to create the plots.

compile_opt idl2
xscm=20 & yscm=28.
PSCAL,'ps',xscm,yscm,name=dirres+dir_region+'/plots/'+sub_region+'/'+id[gg[g]]

device,/bold

; profile
pos=cm2norm(2,17.95,12.5,10,xscm,yscm)
plot,[0],[0],xra=[0,max(length)+max(length)*0.05],yra=[min(bed_elev)-10,max(elev)+10],/xsty,/ysty,xtit='Length (km)         ',ytit='Elevation (m a.s.l.)',pos=pos

oplot,length,gls[0,*],thi=3,col=4
for i=1,cnp-2 do oplot,length,gls[i,*],col=12
oplot,length,bed_elev,thi=4

if advance eq 'y' then area_ini=area_iniconst
ab=dblarr(2,fix(nb/10)) & n=0
for i=0,nb-11,10 do begin
 ab[0,n]=total(area_ini[i:i+9]) & ab[1,n]=total(area[i:i+9])
 n=n+1
     endfor
m=max(length)+max(length)*0.05 & sc=(m/4.)/max(ab[0,*]) & n=0 & e=indgen(nb)*10+e0
for i=0,fix(nb/10)-1 do begin
 polyfill,[m-ab[0,i]*sc,m,m,m-ab[0,i]*sc],[e[n],e[n],e[n+9],e[n+9]],col=15
    polyfill,[m-ab[1,i]*sc,m,m,m-ab[1,i]*sc],[e[n],e[n],e[n+9],e[n+9]],/line_fill,orient=45
 n=n+10
endfor

; statistics
xo=0.35 & yo=0.95 & ys=0.042 & ss=0.9
i=0 & xyouts,x_s(xo),y_s(yo-i*ys),'Area (t=0) (km2): '+string(total(area_ini),fo='(f13.2)')
i=1 & xyouts,x_s(xo),y_s(yo-i*ys),'Area change (%): '+string((area1-total(area_ini))*100/total(area_ini),fo='(i10)')
i=2 & xyouts,x_s(xo),y_s(yo-i*ys),'Volume (t=0) (km2): '+string(volume0,fo='(f8.2)')
i=3 & xyouts,x_s(xo),y_s(yo-i*ys),'Volume change (%): '+string((volume1-volume0)*100/volume0,fo='(i6)')
i=4 & xyouts,x_s(xo),y_s(yo-i*ys),'Terminus (t=0) (masl): '+string(e0,fo='(i4)')
i=5 & xyouts,x_s(xo),y_s(yo-i*ys),'Terminus change (m): '+string(ht1-e0,fo='(i4)')
; -----------------------------
; time series
; Mass balance
pos=cm2norm(2,8.6,12.5,8.2,xscm,yscm)
hh=where(mb gt -90,ch)

if ch gt 0 then begin
plot,[0],[0],xra=[tran[0]-1,tran[1]+1],yra=[min([wb[0:ch-1],mb[0:ch-1],-smelt[0:ch-1],-flux_calv[0:ch-1]])-0.1,max([wb,mb,-smelt])+0.1],/xsty,/ysty,ytit='Mass balance (m w.e.)',pos=pos,/noerase

t=indgen(years)+tran[0]
ii=where(mb ne snoval)
oplot,!x.crange,[0,0],lines=2
oplot,t[ii],mb[ii],thi=6,col=2
oplot,t[ii],wb[ii],thi=6,col=4
oplot,t[ii],-smelt[ii],thi=2,col=11,lines=2
oplot,t[ii],-imelt[ii],thi=2,col=12,lines=3
if max(flux_calv) gt 0 then oplot,t[ii],-flux_calv[ii],thi=6,col=0

; legende
xl=1. & xst=0.35 & yl=0.68 & if max(flux_calv) gt 0 then yst=0.32 else yst=0.26
xsym=0.025 & xsym2=0.07 & xwr=0.13 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd4=0.24 & yd5=0.3
symcor=0.013 & ss=1.15
polyfill, [x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl)], col=1
oplot,[x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst),x_s(xl)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl),y_s(yl)], col=0,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=2,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=4,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd3+symcor),y_s(yl+yst-yd3+symcor)] , col=11,thi=2,lines=2,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd4+symcor),y_s(yl+yst-yd4+symcor)] , col=12,thi=2,lines=3,/noclip
if max(flux_calv) gt 0 then oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd5+symcor),y_s(yl+yst-yd5+symcor)] , col=0,thi=6,/noclip
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Surf. bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Winter bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd3), 'Snow melt', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd4), 'Ice melt', size=ss
if max(flux_calv) gt 0 then xyouts,x_s(xl+xwr),y_s(yl+yst-yd5), 'Frontal Abl.', size=ss

endif
; -----------------------------------
; Area - Volume Plot
anorm=areas/areas[0] & vnorm=volumes/volumes[0]

pos=cm2norm(1.2,0.7,8.3,7.2,xscm,yscm)
plot,[0],[0],xra=[tran[0]-1,tran[1]+1],yra=[-0.02,max([vnorm,anorm])+0.02],/xsty,/ysty,ytit='Norm. Area / Volume (-)',pos=pos,/noerase

oplot,t,anorm,thi=6,col=2
oplot,t,vnorm,thi=6,col=4

; legende
xl=0.03 & xst=0.42 & yl=0.03 & yst=0.14
xsym=0.0 & xsym2=0.06 & xwr=0.09 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd3=0.24
symcor=0.013 & ss=1.15
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=2,thi=6
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=4,thi=6
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Area ('+string(total(area_ini),fo='(f8.2)')+')', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Volume ('+string(volume0,fo='(f8.3)')+')', size=ss

; -----------------------------------
; Elevation distribution
; aggregate values
fp=3.
pst=fix(years/(fp*outst))
if pst ne 0 then begin
;bnp=dblarr(nb,pst)+snoval & acp=bnp & mep=acp & rfp=bnp & elp=bnp & elap=dblarr(2,pst)
for j=0,pst-1 do begin
   for h=0,nb-1 do begin
      elp[h,j]=mean(gls[j*fp:((j+1)*fp-1.),h])
      a=mely[(fp*outst*j):(fp*outst*(j+1)-1),h] & ii=where(a ne noval,ci)
      if ci gt fp*outst/2. then begin
         bnp[h,j]=mean(baly[ii+(fp*outst*j),h])
         acp[h,j]=mean(accy[ii+(fp*outst*j),h])
         mep[h,j]=mean(mely[ii+(fp*outst*j),h])
         rfp[h,j]=mean(refry[ii+(fp*outst*j),h])*10.
      endif
   endfor
   elap[0,j]=mean(ela[(fp*outst*j):(fp*outst*(j+1)-1)])
   elap[1,j]=mean(aar[(fp*outst*j):(fp*outst*(j+1)-1)])
endfor

pos=cm2norm(11.45,0.7,8.5,7.2,xscm,yscm)
plot,[0],[0],xra=[min(-mep[where(mep ne snoval)])-0.1,max(acp)+0.1],yra=[min(elp)-10,max(elp)+10.],/xsty,/ysty,ytit='Elevation (m a.s.l.)',xtit='Mass balance (m w.e. a!E-1!N)',pos=pos,/noerase

oplot,[0,0],!y.crange,lines=2

lin=[0,1,2,3,0]
for j=0,pst-1 do begin
 ii=where(bnp[*,j] ne snoval,ci)
 if ci gt 0 then begin
  oplot,bnp[ii,j],elp[ii,j],thi=4,col=0,lin=lin[j]
  oplot,-mep[ii,j],elp[ii,j],thi=4,col=2,lin=lin[j]
  oplot,acp[ii,j],elp[ii,j],thi=4,col=4,lin=lin[j]
  oplot,rfp[ii,j],elp[ii,j],thi=4,col=12,lin=lin[j]
 endif
 oplot,[x_s(0),x_s(0.2)],[elap[0,j],elap[0,j]],thi=4,lin=lin[j]
 xyouts,x_s(0.21),elap[0,j],'AAR '+string(elap[1,j],fo='(i2)')+'%',size=0.65
endfor

; legende
xl=.55 & xst=0.45 & yl=1. & yst=0.26
xsym=0.025 & xsym2=0.07 & xwr=0.125 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd4=0.24
symcor=0.013 & ss=1
polyfill, [x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl)], col=1
oplot,[x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst),x_s(xl)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl),y_s(yl)], col=0,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=0,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=2,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd3+symcor),y_s(yl+yst-yd3+symcor)] , col=4,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd4+symcor),y_s(yl+yst-yd4+symcor)] , col=12,thi=6,/noclip
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Surface bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Melt', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd3), 'Accumulation', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd4), 'Refreeze (x10)', size=ss

device,/close_file

endif                           ; period long enough
