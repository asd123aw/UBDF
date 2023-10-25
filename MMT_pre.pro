;
;
pro MMT_pre_format, inputfile, outputfile
  ;transform tif file into envi file
  ;open image file
  ENVI_OPEN_FILE, inputfile, r_fid=fid
  ;query image information
  ENVI_FILE_QUERY, fid, dims=dims, nb=nb,bnames = bnames
  ;define band indexes
  bandList = [0,1,2,3,4]
  ;define band names
  bnames = ['band 1','band 2','band 3','band 4','band 5']
  ;save as the defined format
  ENVI_OUTPUT_TO_EXTERNAL_FORMAT,fid = fid,dims = dims, out_name=outputfile,pos = bandList, $
    out_bname=bnames,/ENVI
  ENVI_FILE_MNG, id=fid, /REMOVE
end
;
;

;
;
pro MMT_pre
  
  ;define file paths
  
  fileLST = Dialog_PickFile(title = 'open the landsat:')
  fileMOD =Dialog_PickFile(title = 'open the modis:')
  ;fileLST = 'E:\AAAAALake sum\Alakol\LC08_147028_20210408.tif'
  ;fileMOD = 'E:\AAAAALake sum\Alakol\2021_0408.tif'
  scale = 17 ; resolution of MODIS: 500, resolution of TM: 30, 30*17 = 510
  ;define output file path
  fileout = strsplit(fileLST,'.',/extract)
  fileout = fileout[0]+'_envi'
  
  ;transform tif file into envi file
  MMT_pre_format, fileLST, fileout
  
  ;read landsat image file
  DataLST = READ_TIFF(fileLST)
  ;get dims of the 2D image data
  Dims = size(DataLST)
  NS = Dims[2]
  NL = Dims[3]
  NB = Dims[1]
  
  ;regularize data
  ;resize images to effective dims 
  ;define effective dims (samples and lines that are integer times of scale)
  NS_mod = NS mod scale
  NL_mod = NL mod scale
  NS_effective = NS-NS_mod
  NL_effective = NL-NL_mod
  
  ;resize landsat to effective dims
  outputfile = fileout+'_'+strtrim(string(NS_effective),2)+'_'+strtrim(string(NL_effective),2)
  ;open image file
  ENVI_OPEN_FILE, fileout, r_fid=fid
  ;resize image
  dims = [-1,0,NS_effective-1,0,NL_effective-1]
  pos = [0,1,2,3,4]
  envi_doit, 'resize_doit', $
    fid=fid, pos=pos, dims=dims, $
    interp=0, rfact=[1,1], $
    out_name=outputfile, r_fid=r_fid
  
  ;resample MODIS to effective grids
  DataMOD = READ_TIFF(fileMOD)
  DataOutM = intarr(NB,NS_effective,NL_effective)
  for s = 0, NS_effective-1, scale do begin
  for l = 0, NL_effective-1, scale do begin
    ;get central pixel index
    sample = s+scale/2
    line = l+scale/2
    for b = 0, NB-1 do begin
      DataOutM[b,s:s+scale-1,l:l+scale-1] = reform(DataMOD[b,sample,line])
    endfor
  endfor
  endfor

  ;write image file
  fileoutMODIS = strsplit(fileMOD,'.',/extract)
  fileoutMODIS = fileoutMODIS[0]+'_'+strtrim(string(NS_effective),2)+'_'+strtrim(string(NL_effective),2)
  openw,lun,fileoutMODIS,/get_lun
  writeu,lun,DataOutM
  free_lun,lun
  
  ;open image file
  ENVI_OPEN_FILE, fileout, r_fid=fid
  ;get map information
  map_info = envi_get_map_info(fid=fid)
  ;query file information
  ENVI_FILE_QUERY, fid, dims=dims, nb=nb, $
    data_type=data_type, $
    interleave=interleave
  ;delete image in ENVI
  ENVI_FILE_MNG, id=fid, /REMOVE
  ;setup envi header file
  ENVI_SETUP_HEAD, fname=fileoutMODIS, $
    ns=NS_effective, nl=NL_effective, nb=NB, $
    interleave=interleave, data_type=data_type, $
    map_info=map_info, $
    /write, /open

end
;
;