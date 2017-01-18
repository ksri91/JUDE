;+
; NAME:		JUDE_INTERACTIVE
; PURPOSE:	Driver routine for JUDE (Jayant's UVIT DATA EXPLORER)
; CALLING SEQUENCE:
;	jude_driver, data_dir,$
;		fuv = fuv, nuv = nuv, vis = vis, $
;		start_file = start_file, end_file = end_file,$
;		stage2 = stage2, debug = debug, diffuse = diffuse
; INPUTS:
;	Data_dir 		:Top level directory containing data and houskeeping files for 
;					 UVIT Level 1 data. All data files in the directory will be 
;					 processed.
;	FUV, NUV, VIS	:One and only one of these keywords must be set. The corresponding
;					 data set will be processed
; OPTIONAL INPUT KEYWORDS:
;	Start_file		:The default is to process all the files in the directory
;						structure (start_file = 0). If non-zero, I start with the
;						Nth file.
;	End_file		:By default, I process all the files in the directory.
;					 	If END_FILE is set, I stop with that file.
;	Stage2			:My Level 2 data files include housekeeping information. If
;						If STAGE2 is set, I assume that all files (.fits.gz) in
;						the directory are Level 2 data files.
;   Diffuse			:The default is to improve on the spacecraft pointing by
;						using stars. If I have a diffuse sources, I may do 
;						better by matching that.
;	Debug			: Stops before exiting the program to allow variables to be
;						checked.
;	Defaults		: Runs with default selections.
; OUTPUT FILES:
;	Level 2 data file: FITS binary table with the following format:
;					FRAMENO         LONG      0
;					ORIG_INDEX      LONG      0
;					NEVENTS         INT       0
;					X               FLOAT     Array[1000]
;   				Y               FLOAT     Array[1000]
;   				MC              INT       Array[1000]
;   				DM              INT       Array[1000]
;   				TIME            DOUBLE    0.0000000
;   				DQI             INT       10
;   				ROLL_RA         DOUBLE    0.0000000
;   				ROLL_DEC        DOUBLE    0.0000000
;   				ROLL_ROT        DOUBLE    0.0000000
;   				ANG_STEP        DOUBLE    0.0000000
;   				XOFF            FLOAT     0.00000
;   				YOFF            FLOAT     0.00000
;	FITS image file:	Uncalibrated image file with approximate astrometry.
;							Size is 512x512 times the resolution
;	PNG image file:		With default scaling.
;	Errors.txt	  :Log file.
; NOTES:
;		The latest version of this software may be downloaded from
;		https://github.com/jaymurthy/JUDE with a description at 
;		http://arxiv.org/abs/1607.01874
; MODIFICATION HISTORY:
;	JM: June 26, 2016
;	JM: July 13, 2016 : Fixed an error in selecting files.
;						Either compressed or uncompressed files are ok.
;   JM: July 14, 2016 : More consistency corrections
;	JM:	July 22, 2016 : Added keyword to skip BOD if needed.
;	JM: July 22, 2016 : Corrected frame numbering when overflow.
; 	JM: July 31, 2016 : Changed GTI to DQI
;	JM:	Aug. 03, 2016 : Corrected frame numbering correction.
;	JM: Aug. 03, 2016 : Now run whether BOD or not but write into header
;	JM: Aug. 03, 2016 : Write original file name into header.
;	JM: Sep. 13, 2016 : Write offsets from visible data.
;Copyright 2016 Jayant Murthy
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing, software
;   distributed under the License is distributed on an "AS IS" BASIS,
;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;   See the License for the specific language governing permissions and
;   limitations under the License.
;
;-

pro uv_or_vis, xoff_vis, yoff_vis, xoff_uv, yoff_uv, xoff_sc, yoff_sc, dqi

	print,"n to change defaults."
	ans = get_kbrd(1)
	if (ans eq 'n')then begin
		print,"Do you want to use visible offsets; default is UV? :"
		ans=get_kbrd(1)
		if (ans eq "y")then begin
			xoff_sc = xoff_vis
			yoff_sc = yoff_vis
		endif else begin
			print, "Using UV offsets"
			xoff_sc = xoff_uv
			yoff_sc = yoff_uv
		endelse
	endif
end

pro get_offsets, data_l2, offsets, xoff_vis, yoff_vis, xoff_uv, yoff_uv, $
				xoff_sc, yoff_sc, dqi

;If there exist UV data:
	uv_exist = 0
	if ((min(abs(data_l2.xoff)) lt 100) and (max(abs(data_l2.xoff)) gt 0)) $
		then uv_exist = 1
;Are there VIS data and for how much
	if (min(offsets.att) eq 0)then begin
		vis_exist = 1 
		frac_vis_att = $
			n_elements(where(offsets.att eq 0))/float(n_elements(offsets.att))
	endif else begin
		vis_exist = 0
		frac_vis_att = 0
	endelse

;We use the VIS offsets by default
	if ((vis_exist eq 1) and (frac_vis_att gt .5))then begin
		print,"Will use visible offsets."
		xoff_sc = xoff_vis
		yoff_sc = yoff_vis
;We can't use those points where we have no VIS data
		q = where(offsets.att ne 0, nq)
		if (nq gt 0)then dqi[q] = 2
	endif else vis_exist = 0

;If there are no VIS offsets but there are UV offsets, we use them	
	if ((vis_exist eq 0) and (uv_exist eq 1))then begin
		print,"Will use UV offsets."
		xoff_sc = xoff_uv
		yoff_sc = yoff_uv
		q = where((abs(xoff_sc) gt 500) or (abs(yoff_sc) gt 500), nq)
		if (nq gt 0)then dqi[q] = 2
	endif 
	
	if ((vis_exist eq 0) and (uv_exist eq 0))then begin
		xoff_sc = xoff_uv
		yoff_sc = yoff_uv
	endif
end

pro check_params, params
	tgs  = tag_names(params)
	ntgs = n_elements(tgs)
	ans_no = 0
	while ((ans_no ge 0) and (ans_no lt ntgs))do begin
		for i = 0,n_elements(tgs) - 1 do $
			print,i," ",tgs[i]," ",params.(i)
		read,"Parameter to change? -1 for none: ",ans_no
		if ((ans_no ge 0) and (ans_no le 6))then begin
			ans_val = 0
			read,"New value?",ans_val
			params.(ans_no) = ans_val
		endif
		if ((ans_no ge 7) and (ans_no le 8))then begin
			ans_val = 0.
			read,"New value?",ans_val
			params.(ans_no) = ans_val
		endif
		if ((ans_no gt 9) and (ans_no lt ntgs))then begin
			ans_str = ""
			read,"New value?",ans_str
			params.(ans_no) = ans_str
		endif
	endwhile
end

pro calc_uv_offsets, offsets, xoff_vis, yoff_vis, detector
	if (detector eq "NUV")then begin
		xoff_vis = offsets.xoff
		yoff_vis = -offsets.yoff
	endif else if (detector eq "FUV")then begin
		ang =  35.0000
		xoff_vis = offsets.xoff*cos(ang/!radeg) - offsets.yoff*sin(ang/!radeg)
		yoff_vis = offsets.xoff*sin(ang/!radeg) + offsets.yoff*cos(ang/!radeg)
	endif else begin
		xoff_vis = offsets.xoff*0
		yoff_vis = offsets.yoff*0
	endelse
end

pro plot_diagnostics, data_l2, offsets, data_hdr0, im_hdr, fname, grid, $
					params, ymin, ymax
;Plot diagnostic information	
	erase;	Clear the screen
	
;Find good data	
	q = where(data_l2.dqi eq 0, nq)
	
;Histogram of data but it only makes sense if we have enough points.
	if (nq gt 5) then begin
		h = histogram(data_l2.nevents,min=0,bin=1)
;The mode is the maximum number of elements.
		mode = min(where(h eq max(h[1:*])))
	endif else begin
		h = fltarr(10)
		mode = 0
	endelse

;Plotting Block
	!p.multi = [2,2,3,0,1]
	plot,h,psym=10,yrange=[0,max(h[1:*])*1.5],xrange=[0,params.max_counts*1.5],$
		charsize=2
	oplot,[params.max_counts,params.max_counts],[0,max(h[1:*])*1.5],thick=2
	!p.multi = [3,2,3,0,1]
	plot,data_l2.dqi,psym=1,charsize=2
	!p.multi = [1,2,3,0,1]
	
;UV offsets from self-registration
	xoff_uv  = data_l2.xoff
	yoff_uv  = data_l2.yoff
	
;Offsets from VIS data
	detector = strcompress(sxpar(data_hdr0,"detector"), /remove)	
	calc_uv_offsets, offsets, xoff_vis, yoff_vis, detector
	
;Set the range for plotting the offsets
	q = where(abs(xoff_uv) lt 500,nq)
	if (nq gt 0) then begin
		ymin = min([min(xoff_uv[q]), min(yoff_uv[q])])
		ymax = max([max(xoff_uv[q]), max(yoff_uv[q])])
	endif else begin
		ymin = 0
		ymax = 10
	endelse
	q = where(offsets.att eq 0, nq)
	if (nq gt 0)then begin
		ymin = min([ymin, min(xoff_vis[q]), min(yoff_vis[q])])
		ymax = max([ymax, max(xoff_vis[q]), max(yoff_vis[q])])
	endif

;Plot the offsets
	plot,data_l2.time  - data_l2[0].time, xoff_uv,charsize=2,yrange = [ymin, ymax]
	oplot,data_l2.time - data_l2[0].time, yoff_uv,linestyle=2
	oplot,offsets.time - data_l2[0].time, xoff_vis, col=255
	oplot,offsets.time - data_l2[0].time, yoff_vis, col=255, linestyle = 2

;Show where there is no VIS data
	q = where(offsets.att ne 0, nq)
	if (nq gt 1)then oplot,offsets[q].time - data_l2[0].time, xoff_vis[q], $
		col=65535,psym=3,symsize=3
	if (nq gt 1)then oplot,offsets[q].time - data_l2[0].time, yoff_vis[q], $
		col=65535,psym=3,symsize=3

;Print diagnostics 
	l2_tstart = data_l2[0].time
	ndata_l2 = n_elements(data_l2)
	l2_tend   = data_l2[ndata_l2 - 1].time
	diff = l2_tend - l2_tstart
	if (n_elements(im_hdr) gt 0) then exp_time = sxpar(im_hdr, "exp_time") $
		else exp_time = 0
	str = fname
	str = str + " " + string(long(l2_tstart))
	str = str + " " + string(long(l2_tend))
	str = str + " " + string(long(diff))
	str = str + " " + string(long(exp_time)) 
	str = str + string(mode)
	str = str + " " + string(fix(total(grid)))
	str = strcompress(str)
	print,str
	
end

pro jude_interactive, data_file, data_l2, grid, offsets, uv_base_dir, params = params, $
					defaults = defaults

;Define bookkeeping variables
	exit_success = 1
	exit_failure = 0
	version_date = "Dec. 25, 2016"
	print,"Software version: ",version_date
	
;If we have a window open keep it, otherwise pop up a default window
	device,window_state = window_state
	if (window_state[0] eq 0)then $
		window, 0, xs = 1024, ys = 512, xp = 10, yp = 500

;The image brightness may vary so define a default which may change
	max_im_value = 0.0005
	
;If the default keyword is set we run non-interactively.
	if not(keyword_set(defaults))then defaults = 0
	
;**************************INITIALIZATION**************************

;The parameters are read using JUDE_PARAMS
;Assuming the path is set correctly, a personalized file can be in
;the current directory.
	if (n_elements(params) eq 0)then $
		params = jude_params()	
;Error log: will append to  existing file.
	jude_err_process,"errors.txt",data_file	

;************************LEVEL 2 DATA *********************************
	data_l2   = mrdfits(data_file,1,data_hdr0,/silent)
	ndata_l2  = n_elements(data_l2)
	
;if the keywords exist, read the starting and ending frame from the 
;data file
	params.min_frame = sxpar(data_hdr0, "MINFRAME")
	params.max_frame = sxpar(data_hdr0, "MAXFRAME")
	if ((params.max_frame eq 0) or (params.max_frame gt (ndata_l2 -1)))then $
		params.max_frame = ndata_l2 - 1
	start_frame = params.min_frame
	end_frame 	= params.max_frame
	save_dqi  = data_l2.dqi
	dqi       = data_l2.dqi
	
;Calculate the median from the data. This is photon counting so sigma
; = sqrt(median). I allow 5 sigma.
	q = where(data_l2.dqi eq 0, nq)

	if (nq gt 10)then begin
		dave = median(data_l2[q].nevents)
		dstd = sqrt(dave)
		params.max_counts = dave + dstd*5

;Name definitions
		fname = file_basename(data_file)
		f1 = strpos(fname, "level1")
		f2 = strpos(fname, "_", f1+8)
		fname = strmid(fname, 0, f2)
		image_dir   = uv_base_dir + params.image_dir
		events_dir  = uv_base_dir + params.events_dir
		png_dir     = uv_base_dir + params.png_dir
		image_file  = image_dir   + fname + ".fits.gz"
		
;If the image file exists I use it. 
		if (file_test(image_file) ne 0)then begin
			grid = mrdfits(image_file, 0, im_hdr)
			if (max(grid) eq 0)then begin
				grid = fltarr(2048, 2048)
				print, "No data in the image"
			endif
		endif else grid = fltarr(2048, 2048)

;Read the VIS offsets if they exist. If they don't exist, set up a 
;dummy array and header.
		offsets = mrdfits(data_file, 2, off_hdr)
		if (n_elements(offsets) le 1)then begin
			offsets = replicate({offsets, time:0d, xoff:0., yoff:0., att:0}, ndata_l2)
			offsets.time = data_l2.time
			offsets.att  = 1
			fxbhmake,off_hdr,ndata_l2,/initialize
			sxaddhist,"No offsets from visible",off_hdr, /comment
		endif
		detector = strcompress(sxpar(data_hdr0,"detector"), /remove)
		calc_uv_offsets, offsets, xoff_vis, yoff_vis, detector
		xoff_uv = data_l2.xoff
		yoff_uv = data_l2.yoff
			
check_diag:
;Plot the image plus useful diagnostics
		plot_diagnostics, data_l2, offsets, data_hdr0, im_hdr, fname, grid, $
					params, ymin, ymax
		tv,bytscl(rebin(grid, 512, 512), 0, max_im_value)
		
;Check to see if there is any good data
		q = where(data_l2.dqi eq 0, nq)
		if (nq eq 0)then begin
			if (defaults eq 0)then begin
				print,"No good data. Press any key to continue."
				tst = get_kbrd(1)
			endif else print,"No good data, continuing."
			ans = "n"
		endif else ans = "y"
		
;********************* BEGIN REPROCESSING ***********************		
		if (ans eq "y")then begin

;Set parameters for reprocessing
			if (defaults eq 0)then CHECK_PARAMS, params
			
;Calculate integration times from parameters and plot.
			params.max_frame = params.max_frame < (ndata_l2 - 1)
			if (params.max_frame gt 0) then begin
				int_time = data_l2[params.max_frame].time - data_l2[0].time
			endif else int_time = 0
			oplot,[int_time, int_time],[ymin,ymax],thick=3,col=255
			int_time = data_l2[params.min_frame].time - data_l2[0].time
			oplot,[int_time, int_time],[ymin,ymax],thick=3,col=255

			GET_OFFSETS,data_l2, offsets, xoff_vis, yoff_vis, $
							xoff_uv, yoff_uv, $
							xoff_sc, yoff_sc, dqi
							
;Figure out what we want to do.
			if (defaults eq 0)then $
				UV_OR_VIS, xoff_vis, yoff_vis, xoff_uv, yoff_uv, $
					  xoff_sc, yoff_sc, dqi
		
			run_registration = 'n'
			if (defaults eq 0)then begin
				print,"Run registration (y/n)? Default is n."
				run_registration = get_kbrd(1)
			endif
			
;*************************DATA REGISTRATION*******************************	
			if (run_registration eq 'y')then begin
				if (strupcase(detector) eq "FUV")then $
					mask_threshold = params.ps_threshold_fuv else $
					mask_threshold = params.ps_threshold_nuv
					
				ans  = "p"
				print,"Default is to run for point sources, d for diffuse registration"
				if (defaults eq 0)then ans=get_kbrd(1)
;Point source registration
				par = params
;Rebin for resolution of 1 because that increases S/N
				par.resolution = 1
				mask_file = uv_base_dir + params.mask_dir + fname + "_mask.fits.gz"
				
				if (file_test(mask_file))then begin
					print,"reading mask file"
					mask = mrdfits(mask_file, 0, mask_hdr)
					mask = rebin(mask, 512*par.resolution, 512*par.resolution)
				endif else mask =fltarr(512*par.resolution,512*par.resolution)+1.
				tv,bytscl(rebin(grid*mask,512,512),0,max_im_value)

if (ans ne "d")then begin
					tst = jude_register_data(data_l2, out_hdr, par, /stellar,	$
									bin = params.coarse_bin, mask = mask,		$
									xstage1 = xoff_sc*par.resolution, $
									ystage1 = yoff_sc*par.resolution, $
									threshold = mask_threshold)					
				endif else begin
					tst = jude_register_data(data_l2, out_hdr, par,				$
									bin = params.coarse_bin, 					$
									mask = mask, 								$
									xstage1 = xoff_sc*par.resolution, $
									ystage1 = yoff_sc*par.resolution,		$
									threshold = mask_threshold)
				endelse
				xoff_sc = data_l2.xoff/par.resolution
				yoff_sc = data_l2.yoff/par.resolution
			endif
;******************************END REGISTRATION BLOCK******************
			
;Final image production
			par = params
			if (defaults eq 0)then begin
				data_l2.dqi = dqi
				nframes = jude_add_frames(data_l2, grid, pixel_time,  params, $
							xoff_sc*params.resolution, yoff_sc*params.resolution,$
							/notime, debug = 100)
			endif else begin
				data_l2.dqi = dqi
				nframes = jude_add_frames(data_l2, grid, pixel_time,  params, $
							xoff_sc*params.resolution, yoff_sc*params.resolution, /notime)
			endelse
			
			print,"Total of ",nframes," frames ",nframes*.035," seconds"
			if (defaults eq 0) then ans = "y" else begin
				ans = "n"
				tv,bytscl(rebin(grid,512,512),0,max_im_value)
			endelse			
			while (ans eq "y") do begin
				tv,bytscl(rebin(grid,512,512),0,max_im_value)
				print,"Redisplay? "
				ans=get_kbrd(1)
				if (ans eq "y")then read,max_im_value
			endwhile
			if (defaults eq 0)then begin
				ans = "n"
				print,"Write files out (this may take some time)?"
				ans = get_kbrd(1)
			endif else ans = "y"
			if (ans eq "y")then begin
;Until getting the time issues sorted out I will leave this as no time calculation.
				data_l2.dqi = dqi
				nframes = jude_add_frames(data_l2, grid, pixel_time,  params, $
				xoff_sc*params.resolution, yoff_sc*params.resolution, /notime)

;File definitions
				fname = file_basename(data_file)
				fname = strmid(fname,0,strlen(fname)-8)
				imname = file_basename(image_file)
				imname = strmid(imname, 0, strlen(imname) - 8)
				if (file_test(events_dir) eq 0)then spawn,"mkdir " + events_dir
				if (file_test(image_dir) eq 0)then spawn,"mkdir "  + image_dir
				if (file_test(png_dir) eq 0) then spawn,"mkdir "   + png_dir

;Make the basic header
				mkhdr, out_hdr, grid
				jude_create_uvit_hdr,data_hdr0,out_hdr

;Write PNG file
				t = uv_base_dir + params.png_dir+fname+".png"
				write_png,t,tvrd()
			
;Write FITS image file
				nom_filter = strcompress(sxpar(out_hdr, "filter"),/remove)
				sxaddpar,out_hdr,"NFRAMES",nframes,"Number of frames"
;Check the exposure time
				q = where(data_l2.dqi eq 0, nq)
				if (nq gt 0)then begin
					avg_time = $
					(max(data_l2[q].time) - min(data_l2[q].time))/(max(q) - min(q))
				endif else avg_time = 0
			
				sxaddpar,out_hdr,"EXP_TIME",nframes * avg_time, "Exposure Time in seconds"
				print,"Total exposure time is ",nframes * avg_time
				nom_filter = nom_filter[0]
				sxaddpar,out_hdr,"FILTER",nom_filter
				sxaddpar,out_hdr,"MINEVENT",params.min_counts,"Counts per frame"
				sxaddpar,out_hdr,"MAXEVENT",params.max_counts,"Counts per frame"
				sxaddpar, out_hdr,"MINFRAME", params.min_frame,"Starting frame"
				sxaddpar, out_hdr,"MAXFRAME", params.max_frame,"Ending frame"
				sxaddhist,"Times are in Extension 1", out_hdr, /comment
				sxaddhist,fname,out_hdr
								
;Write image file
				t = uv_base_dir + params.image_dir + imname + ".fits"
				print,"writing image file to ",t
				mwrfits,grid,t,out_hdr,/create
				mwrfits,pixel_time,t

;Write FITS events list
				t = uv_base_dir + params.events_dir + fname + ".fits"
				temp = data_l2
				temp.xoff = xoff_sc
				temp.yoff = yoff_sc
				temp.dqi = save_dqi
				print,"writing events file to ",t
;We've looked and these are the parametes last used.
				sxaddpar, data_hdr0,"MINFRAME", params.min_frame,$
						"Recommended starting frame"
				sxaddpar, out_hdr,"MAXFRAME", params.max_frame,$
						"Recommended ending frame"
				mwrfits,temp,t,data_hdr0,/create,/no_comment
				if (n_elements(off_hdr) gt 0)then begin
					mwrfits,offsets,t,off_hdr,/no_comment
				endif else mwrfits,offsets,t
			endif
			
			if (defaults eq 0)then begin
				ans = "n"
				print,"Do you want to run with different parameters?"
				ans=get_kbrd(1)
			endif else ans = "n"
			data_l2.xoff = xoff_sc
			data_l2.yoff = yoff_sc
			data_l2.dqi = save_dqi
			if (ans eq "y")then goto, check_diag
		endif
	endif else print,data_file, "Not enough good points to process"
noproc:
end