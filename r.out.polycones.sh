#!/bin/bash

############################################################################
#
# MODULE:       r.out.polycones
# AUTHOR(S):    Peter Loewe <loewe AT gisix . com>
# PURPOSE:      Create a set of gores from a global EPSG4326 map 
#               
#               
#               
# COPYRIGHT:    (c) 2014 Peter Loewe and the GRASS DEVELOPMENT TEAM
#
#               This program is free software under the GNU General Public
#               License (>=v2). Read the file COPYING that comes with GRASS
#               for details.
#
# updates:
#
# 2014-07-15  (PL):Initial Version
# 2014-07-18  (PL):Refactoring
# 2014-07-27  (PL):Working version
# 2014-07-29  (PL):Work begins: Width/Height; overlap; outline
# 2014-08-04  (PL): Polar circles begun
# 2014-09-22  (PL): Multiple gores per sheets
# 2014-09-25  (PL): Purging old code
# 2014-10-14  (PL): Refactoring
# 2014-10-23  (PL): Integration of triple loops: initial/loop/last
# 2014-10-28  (PL): All-in-one-sheet works, one gore-per-sheet works, mutliple gores per sheet work
# 2014-10-29  (PL): Polar circles reintroduced
# 2014-10-31  (PL): Retirement of -m flag for explicit override to "all in one sheet". SET-option default=0 now suffices.
# 2014-11-02  (PL): Requirement check for GMT added
# 2014-11-05  (PL): Renamsing of parameters: map->input, sheet->papersize, set-> sheet, work on gore schemes != 12, WIDTH/HEIGHT fixed
# 2014-11-05  (PL): Dots per Inch parameter included
# 2014-11-19  (PL): Development line reopened (triggered by Yann). Format parameter added. Goal: Release as Add-on for GRASS6.4.x
# 2014-11-21  (PL): Renamed to r.out.polycones. Output formats pdf/png/ps implemented, DPI for PNG export included, faisafe to require gs
# 2014-11-23  (PL): Cleanup of parameters. gores -> cones / papersize-> paper
# 2014-11-27  (PL): Work on x-shift parameter
# 2014-11-27  (PL): X-shift parameter settings included for each Gore number
# 2014-11-14  (PL): PNG export via ps2raster: fixes bounding box issues
# 2014-12-21  (PL): Added s-switch and xdelta-padding from d.out...20141216
# 2015-01-05  (PL): Support for white background for PNG output (before: black, waste of printer toner) + gore overlap
# 2015-01-26  (PL): Change from #!/bin/sh to #!/bin/bash for hostsharing environment; grdimage calls augmented by "GMT grdimage"; issue: parameters complaint at grdimage  

############################################################################
#%module
#%  description: Create a set of gores from a global EPSG4326 map  
#%end


#%flag
#%  key: s
#%  description: Seperate adjacent gores printed side by side (default: connect)
#%end


#%flag
#%  key: o
#%  description: Enable overlap of gores on the eastern side  (default: none)
#%end


#%option
#% key: input
#% type: string
#% gisprompt: old,cell,raster
#% description: Global map
#% required : yes
#%end

#%option
#% key: output
#% type: string
#% gisprompt: string
#% description: Gore file
#% required : yes
#%end

#%option
#% key: width
#% type: string
#% gisprompt: string
#% description: Output Map width in mm
#% required : no
#% answer : -1
#%end

#%option
#% key: height
#% type: string
#% description: Output Map width in mm
#% answer: -1
#% required : no
#%end

# #%option
# #% key: overlap
# #% type: string
# #% gisprompt: string
# #% description: Overlap of gores in decimal degrees.
# #% required : no
# #% answer : 0
# #%end

#%option
#% key: paper
#% type: string
#% description: Paper format
#% options: A10,A9,A8,A7,A6,A5,A4,A3,A2,A1,A0,B1,B2,B3,B4,B5,archA,archB,archC,archD,archE,flsa,letter,halfletter,legal,tabloid,ledger,statment
#% answer: A4
#% required : no
#%end

#%option
#% key: dpi
#% type: string
#% description: Paper format
#% options: 1200,800,600,300,150,100,50
#% answer: 300
#% required : no
#%end

#%option
#% key: cones
#% type: string
#% description: Number of cones (gores)
#% options: 4,6,8,10,12,14,16
#% answer: 12
#% required : no
#%end

#20141105:  gore numbers > 16 fail: first loop iteration doesn't complete


#%option
#% key: sheet
#% type: string
#% description: Number of gores per sheet
#% options: 0,1,2,3,4,5,6,7,8
#% answer: 0
#% required : no
#%end
#^ this will be used to define the number of gores per printed out sheet (extension to m flag)

#%option
#% key: units
#% type: string
#% description: Units for height / width: (p)oints (default), (i)nches, (m)etres, (c)entimetres
#% options: c,i,m,p
#% answer: c
#% required : no
#%end

#%option
#% key: format
#% type: string
#% options: png,pdf,ps
#% description: Output format: Options are PNG, PDF and Postscript
#% required : no
#% answer: pdf
#%end

#GORE_OUTPUT_FORMAT=${GIS_OPT_FORMAT}

#Flags:
#FLAG_DRAW_CIRCLES=${GIS_FLAG_C}
FLAG_GORE_DELTA=${GIS_FLAG_S}
FLAG_GORE_OVERLAP=${GIS_FLAG_O}


#Options:
RAST_INPUT_MAP=${GIS_OPT_INPUT}
GORE_OUTPUT_FILE=${GIS_OPT_OUTPUT}
GORE_PAPER_WIDTH=${GIS_OPT_WIDTH}
GORE_PAPER_HEIGHT=${GIS_OPT_HEIGHT}
GORE_PAPER_FORMAT=${GIS_OPT_PAPER}
GORE_TOTAL=${GIS_OPT_CONES}
GORE_PAPER_DPI=${GIS_OPT_DPI}
GORE_PAPER_UNITS=${GIS_OPT_UNITS}
GORE_SHEET_MAX=${GIS_OPT_SHEET}
GORE_OUTPUT_FORMAT=${GIS_OPT_FORMAT}



#----------------------------------------------------------------
export GIS_LOCK=$$
#----------------------------------------------------------------


######################## FUNCTIONS #######################################

########################################################################
# name: error_routine
# purpose: If an error occurs, exit gracefully.
#

error_routine () {
 echo "r.out.polycones ERROR: $1"
 exit 1
}


#########################################################################
# name: require_gs
# purpose: Terminate execuation if gs package not installed.

function require_gs () {
 if [ ! -x `which gs` ] ; then
   error_routine "Ghostscript (gs) required. Please install."
   #exit 1
 fi
}


#########################################################################
# name: require_gmt
# purpose: Terminate execuation if gmt package not installed.

function require_gmt () {
 if [ ! -x `which gmt` ] ; then
   error_routine "Generic Mapping Tools (gmt) required. Please install."
   #exit 1
 fi
}

#########################################################################
# name: require_latlon
# purpose: Require EPSG4326 LatLon location.

function require_latlon () {
 LATLON_TEST=`g.proj -j | grep +proj | sed 's/+proj=//'`
 if [ "$LATLON_TEST" != "longlat"  ] ; then
   error_routine "Needs a latitude longitude location to run."
   #exit 1
 fi
}

########################################################################
# name: define_paper_media_parameter
# purpose: set papersize_width_height

function define_paper_media_parameter () {
 if [[ ($GORE_PAPER_WIDTH != -1)&&($GORE_PAPER_HEIGHT != -1) ]] ; then
  #echo "--------- WIDTH + HEIGHT SET"
  PAPER_MEDIA_STRING="--PS_MEDIA=${GORE_PAPER_WIDTH}${GORE_PAPER_UNIT}x${GORE_PAPER_HEIGHT}${GORE_PAPER_UNIT} --DOTS_PR_INCH=$GORE_PAPER_DPI"
 fi
 
 #XOR
 if [[ (($GORE_PAPER_WIDTH -eq -1)&&($GORE_PAPER_HEIGHT != -1))||(($GORE_PAPER_WIDTH != -1)&&($GORE_PAPER_HEIGHT -eq -1)) ]] ; then
  #echo "--------- WIDTH + HEIGHT CORRUPT"  
  error_routine "export media dimensions faulty."
 fi

 if [[ ($GORE_PAPER_WIDTH -eq -1)&&($GORE_PAPER_HEIGHT -eq -1) ]] ; then
  #echo "---------  USE PAPERSIZE"
  #OUTSTRING="--PAPER_MEDIA=${GORE_PAPER_WIDTH}${GORE_PAPER_UNIT}x${GORE_PAPER_HEIGHT}${GORE_PAPER_UNIT}"
  PAPER_MEDIA_STRING="--PS_MEDIA=$GORE_PAPER_FORMAT --DOTS_PR_INCH=$GORE_PAPER_DPI"
 fi      

#GMT-related background 
#--PAPER_MEDIA:
#For a completely custom format (e.g., for large format plotters) you may also specify Custom_WxH, 
#where W and H are in points unless you append a unit to each dimension (c, i, m or p [Default]). 

}


#########################################################################
# name: derive_pdf
# purpose: Derive PDF from PS output
# ACTION: Extend to derive_output, based on GORE_OUTPUT_FORMAT

#function derive_pdf {
#foo=`ps2pdf -q $1`
#############
## Resize PDF
#baz=`pdfcrop --noverbose $2 $3`
##CLEANUP
#rm -f $1 $2
#}                    


#########################################################################
# name: derive_output

function derive_output {
#$1 = ${TEMP_SHEETS}_${GORE_SHEET_ID}
#$2 = ${OUTPUT_SHEETS}_${GORE_SHEET_ID}

echo "-----------------------------------------------"
echo "derive_output: *$1* ** $2**"

format_option_png="png"
format_option_pdf="pdf"
format_option_ps="ps"

#INITIAL_POSTSCRIPT="$1.ps"
#INITIAL_POSTSCRIPT="$1"
#INITIAL_FILENAME=`echo $INITIAL_POSTSCRIPT | sed 's/\.ps//g'`
INITIAL_FILENAME="$1"
INITIAL_POSTSCRIPT="$1.ps"

OUTPUT_FILENAME="$2"


if [[ "$GORE_OUTPUT_FORMAT" == "$format_option_pdf" ]] ; then
 INTERMEDIATE_PDF="$INITIAL_FILENAME.pdf"
 RESULT_PDF="$OUTPUT_FILENAME.pdf"
 #echo "ps2pdf -q $INITIAL_POSTSCRIPT"
 foo=`ps2pdf -q $INITIAL_POSTSCRIPT`
 #echo "--ps2pdf completeted--"
 ############
 # Resize PDF
 baz=`pdfcrop --noverbose $INTERMEDIATE_PDF $RESULT_PDF`
   
 #cleanup
 rm -f $INTERMEDIATE_PDF
fi


if [[ "$GORE_OUTPUT_FORMAT" == "$format_option_png" ]] ; then
 #require_gs
 RESULT_PNG="$OUTPUT_FILENAME.png"
 #http://scriptdemo.blogspot.de/2012/06/bash-ps2png-convert-ps-to-png-format.html
 ##gs -q -r$GORE_PAPER_DPI -dTextAlphaBits=4 -sDEVICE=png16m -sOutputFile=$RESULT_PNG -dBATCH -dNOPAUSE $INITIAL_POSTSCRIPT
 ##echo "gs -q -r$GORE_PAPER_DPI -dTextAlphaBits=4 -sDEVICE=png16m -sOutputFile=$RESULT_PNG -dBATCH -dNOPAUSE $INITIAL_POSTSCRIPT"
# ps2raster -f:B255/255/255 -A -E$GORE_PAPER_DPI -TG $INITIAL_POSTSCRIPT 
 ps2raster --COLOR_BACKGROUND=255/255/255 --COLOR_NAN=255/255/255 -PS_PAGE_COLOR=255/255/255 -A -E$GORE_PAPER_DPI -TG $INITIAL_POSTSCRIPT
 
 mv $INITIAL_FILENAME.png $RESULT_PNG
fi

if [[ "$GORE_OUTPUT_FORMAT" == "$format_option_ps" ]] ; then
 RESULT_PS="$OUTPUT_FILENAME.ps"
 mv $INITIAL_POSTSCRIPT $RESULT_PS
fi

rm -f $INITIAL_POSTSCRIPT

}

#########################################################################
# name: derive_region_settings
# purpose: Get the GRASS region parameters for use in GMT

function derive_region_settings {
export `g.region -g`
# This does explicitly NOT zoom to the input map:
# this allows for a "black planet scenario" where only a subset of the globe is covered by the map
# TBD:the background color has to be ensured

#define region variables:
GRASS_REGION_N=$n
GRASS_REGION_S=$s
GRASS_REGION_E=$e
GRASS_REGION_W=$w
GRASS_REGION_LAT_EXPANSE=`echo $e - $w | bc`
#echo "$GRASS_REGION_N $GRASS_REGION_S $GRASS_REGION_W $GRASS_REGION_E ** $GRASS_REGION_LAT_EXPANSE **"
#exit
}

#
##
###
####
######################## END OF FUNCTIONS ##########################################




#################################
# is GRASS running ? if not: abort
#################################
if [ -z "$GISBASE" ] ; then
  error_routine "You must be in GRASS to run this program."
fi

#################################
# Requirements

#GMT installed ?
require_gmt

# Longlat location ?
require_latlon


#################################
# if no paramters are provided by the user fire up the gui
if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec $GISBASE/bin/g.parser "$0" "$@"
fi

#################################
# Output paper consistency check
define_paper_media_parameter



#################################
# Set Export Environment for DRAPE and DEM

ISTRUE=1
ISFALSE=0
ISNIL=-1

###
### TBD:
###      Figure a smart way to deal with the offset between the gores - needs to be computed. 

################################
# Derive R G B channels of input raster 
r.mapcalc "${RAST_INPUT_MAP}.red=r#${RAST_INPUT_MAP}"
r.mapcalc "${RAST_INPUT_MAP}.green=g#${RAST_INPUT_MAP}"
r.mapcalc "${RAST_INPUT_MAP}.blue=b#${RAST_INPUT_MAP}"

################################
# define file names for channel export files which will work for GMT
GORE_GRID_R=${GORE_OUTPUT_FILE}_255_red.grd
GORE_GRID_G=${GORE_OUTPUT_FILE}_255_green.grd
GORE_GRID_B=${GORE_OUTPUT_FILE}_255_blue.grd


###############################
# write our R G B channels as rasters so GMT can use them later
r.out.bin -ih --q in=${RAST_INPUT_MAP}.blue out=${GORE_GRID_B}
r.out.bin -ih --q in=${RAST_INPUT_MAP}.red out=${GORE_GRID_R}
r.out.bin -ih --q in=${RAST_INPUT_MAP}.green out=${GORE_GRID_G}
      

########################
# Define temp files
TEMP_SHEETS=${GORE_OUTPUT_FILE}_temp_sheets_$$
#TEMP_COMBO_PS=${GORE_OUTPUT_FILE}_temp_combo_$$.ps
TEMP_COMBO=${GORE_OUTPUT_FILE}_temp_combo_$$
TEMP_COMBO_PS=${TEMP_COMBO}.ps
TEMP_SHEETS=${GORE_OUTPUT_FILE}_temp_sheets_$$
TEMP_SHEETS_PS=${TEMP_SHEETS}.ps
TEMP_COMBO_PDF=${GORE_OUTPUT_FILE}_temp_combo_$$.pdf
TEMP_SHEETS_PDF=${GORE_OUTPUT_FILE}_temp_sheets_$$.pdf

########################
# Define output files

OUTPUT_COMBO="${GORE_OUTPUT_FILE}_combo"
OUTPUT_COMBO_PDF="$OUTPUT_COMBO.pdf"
OUTPUT_COMBO_PNG="$OUTPUT_COMBO.png"

OUTPUT_SHEETS="${GORE_OUTPUT_FILE}_sheets"
OUTPUT_SHEETS_PDF="$OUTPUT_SHEETS.pdf"

#echo "OUTPUT= ***$OUTPUT_COMBO *** $OUTPUT_COMBO_PDF *** $OUTPUT_COMBO_PNG *** $OUTPUT_SHEETS *** $OUTPUT_SHEETS_PDF "


#######################
#Cleanup
rm -f $TEMP_COMPO_PS $TEMP_COMBO_PDF $TEMP_SHEETS_PS $TEMP_SHEETS_PDF
#^^^ still needed ?


################
#Define stepping
################

#Get GRASS region boundaries
derive_region_settings


step=`echo $GRASS_REGION_LAT_EXPANSE/${GORE_TOTAL} | bc`

#xshift=`echo "0.0155*$step" | bc`
#^!!! About right for FOUR ******************
#     too wide for eights
#xshift=`echo "0.01425*$step" | bc`
#^!!! Works for EIGHT
#xshift=`echo "0.014625*$step" | bc`
#^!!!! works for SIX
#^^^tbd: why 0.014 hardwired ? 

#######################################
## Define x-shift

case "$GORE_TOTAL" in

4)  xfactor=0.0155
    xdelta=0.002
            ;;
6)  xfactor=0.014625
    xdelta=0.002
            ;;
8)  xfactor=0.01425
    xdelta=0.002
            ;;
10)  xfactor=0.014125
     xdelta=0.002
            ;;
12)  xfactor=0.014
     xdelta=0.002
            ;;
14)  xfactor=0.014
     xdelta=0.002
            ;;
16)  xfactor=0.014
     xdelta=0.002
            ;;
*) xfactor=0.02
   xdelta=0.002
            ;;
#Fallback. Should never apply
esac

######################################
# Delta flag set ?                                                                                                   
if [[ $FLAG_GORE_DELTA -eq 1 ]] ; then
  xshift=`echo "($xfactor + $xdelta)*$step" | bc`
else
  xshift=`echo "$xfactor*$step" | bc`
fi

######################################
# Overlap flag set ?
if [[ $FLAG_GORE_OVERLAP -eq 1 ]] ; then
 gore_overlap=1.01
 # enable eastern overlap factor 0.01
else
 gore_overlap=1.0
 #no overlap
fi

    
##############
# Define counters
##############

GORE_PER_SHEET_COUNTER=0
GORE_SHEET_ID=1

############################################################################################
#### GORE LOOP #############################################################################
############################################################################################
############################################################################################

GORE_TOTAL_MINUS_ONE=`echo "${GORE_TOTAL}-1" | bc`

for i in `seq 1 ${GORE_TOTAL_MINUS_ONE}`
do

    ##############
    # DEFINE GORE
    ##############

    lon_left=`echo "scale=4; ${GRASS_REGION_W}+($i-1)*$step" | bc`
    lon_center=`echo "scale=4; ${GRASS_REGION_W}+($i-0.5)*$step" | bc`
    lon_right=`echo "scale=4; ${GRASS_REGION_W}+($i*$step)*$gore_overlap" | bc`
    
#    echo ""
#    echo "[$i: left=$lon_left center=$lon_center right=$lon_right ]"     

    #if [[ $FLAG_MULTI_SHEET -eq $ISFALSE ]] ; then
    if [[ $GORE_SHEET_MAX -eq 0 ]] ; then
      ##############
      # SINGLE SHEET
      ##############
      
      #this command opens the writing of the only sheet that will be written to in the process
      
      #echo "[ --PS_MEDIA=$GORE_PAPER_FORMAT -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i ]   "
      
      if [[ $i -eq 1 ]] ; then
         #echo "  ALLINONE: Erster Gore $i"
         GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B} $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i -K  > $TEMP_COMBO_PS

         ###########
         ## Polar circles: Include in Postscript file
         ## 
         ## ! Single file: Append BEFORE the Page is closed !
         ## northern circle:
         #echo 45 $lon_center | psxy -R$lon_left/$lon_right/-90/90 -Jt$lon_center/0.014i -X"${xshift}"i -Sc5.0 -W20p,red -O -K >> $TEMP_COMBO_PS
         #^doesn't print a thing, but affects the layout of the sheet.
         ## southern circle
         #echo -90 $lon_center | psxy -OK -J -R -Sc20p -W4p,red  >> $TEMP_COMBO_PS

      else      
         #echo "  ALLINONE: Gore Loop: $i"         
         GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B} $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i -O -K  >> $TEMP_COMBO_PS    
         
         ###########
         ## Polar circles: Include in Postscript file
         ## 
         ## ! Single file: Append BEFORE the Page is closed !
         ## northern circle:
         #echo 90 $lon_center | psxy -OK -J -R -Sc20p -W4p,red >> $TEMP_COMBO_PS
         ## southern circle
         #echo -90 $lon_center | psxy -OK -J -R -Sc20p -W4p,red  >> $TEMP_COMBO_PS
      fi
      
    else
      ##############
      # MULTI SHEETS
      ##############     
      
      GORE_PER_SHEET_COUNTER=`echo "$GORE_PER_SHEET_COUNTER+1" | bc`
  
      if [[ $GORE_PER_SHEET_COUNTER -eq $GORE_SHEET_MAX  ]] ; then
        
        #echo "--------------------------------------------------"
        #echo "Gore Sheet Counter has reached Maxvalue = $GORE_SHEET_MAX"
        #echo "Writeout + Reset Gor-per-Sheet counter + Gore sheet number to be upped to $GORE_SHEET_ID"
        #echo "--------------------------------------------------"
    
        if [[ $GORE_SHEET_MAX -eq 1 ]] ; then
      
         #echo "  MULTI CLOSING: Single"
         GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B} $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -K  > ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps
         derive_output ${TEMP_SHEETS}_${GORE_SHEET_ID} ${OUTPUT_SHEETS}_${GORE_SHEET_ID}
         #ISSUE      
        else
         #echo "  MULTI CLOSING"
         GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}  $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i  -O >> ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps
         derive_output ${TEMP_SHEETS}_${GORE_SHEET_ID} ${OUTPUT_SHEETS}_${GORE_SHEET_ID}
         #ISSUE
        fi
    
        GORE_PER_SHEET_COUNTER=0  #Counter-im-Blatt wieder zurücksetzen.
        GORE_SHEET_ID=`echo "$GORE_SHEET_ID+1" | bc` #Blattnummer hochzaehlen
      else
        #echo "--------------------------------------------------"
        #echo "Gore Sheet Counter ** $GORE_PER_SHEET_COUNTER ** below $GORE_SHEET_MAX"   
        #echo "--------------------------------------------------"
        if [[ $GORE_PER_SHEET_COUNTER -eq 1 ]] ; then
          #echo "    MULTI: RAMP UP: START NEW PAGE"
          GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}  $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -K  > ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps

        else
          #echo "     MULTI: RAMP UP: WRITE TO EXISTING PAGE"
          GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}  $PAPER_MEDIA_STRING  -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i  -O -K >> ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps
        fi
      fi
    fi

    final_step=`echo "($i+1)" | bc`    
done




############################################################################################
#### FINAL GORE ############################################################################
############################################################################################
############################################################################################

##############
# DEFINE FINAL GORE

lon_left=`echo "${GRASS_REGION_W}+($GORE_TOTAL-1)*$step" | bc`
lon_right=`echo "${GRASS_REGION_W}+$GORE_TOTAL*$step" | bc`
lon_center=`echo "${GRASS_REGION_W}+($GORE_TOTAL-0.5)*$step" | bc`


#echo ""
#echo "[$GORE_TOTAL: left=$lon_left center=$lon_center right=$lon_right]"        
#echo ""
    if [[ $GORE_SHEET_MAX -eq 0 ]] ; then    
      ##############
      # SINGLE SHEET FINAL
      ##############
      #echo "  ALLINONE: FINAL "         
      GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B} $PAPER_MEDIA_STRING -R$lon_left/$lon_right/-90/90 -Jt$lon_center/0.014i -X"${xshift}"i  -O >> $TEMP_COMBO_PS
      derive_output $TEMP_COMBO  $OUTPUT_COMBO
      #^possible issue here: the loop used variables plus string extensions. not so here. where come the vars from ?
      
    else
      ##############
      # MULTI SHEETS FINAL
      ##############     
      GORE_PER_SHEET_COUNT_NOW=`echo "$GORE_PER_SHEET_COUNTER+1" | bc`
        #echo "MULTI FINAL: $GORE_PER_SHEET_SHEET_COUNTER  -->  $GORE_PER_SHEET_COUNT_NOW -eq 1 ? y->single else> multiclose"    
        if [[ $GORE_PER_SHEET_COUNT_NOW -eq 1 ]] ; then
      
         #echo "  MULTI FINAL: 1-PAGER"
         GMT grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}  $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i  -K > ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps
       
        else
         #echo "  MULTI FINAL: MultiPage"
         grdimage ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}  $PAPER_MEDIA_STRING -R$lon_left/$lon_right/$GRASS_REGION_S/$GRASS_REGION_N -Jt$lon_center/0.014i -X"${xshift}"i  -O >> ${TEMP_SHEETS}_${GORE_SHEET_ID}.ps

        fi
        derive_output ${TEMP_SHEETS}_${GORE_SHEET_ID} ${OUTPUT_SHEETS}_${GORE_SHEET_ID}     
        #ISSUE
    fi


####################################################
###  CLEANUP SECTION 
#Cleanup combo intermediates files:
rm -f $TEMP_SHEETS_PS $TEMP_SHEETS_PDF

#cleanup GRD files:
rm -f ${GORE_GRID_R} ${GORE_GRID_G} ${GORE_GRID_B}


#Cleanup GRASS rasters
g.remove --q rast=${RAST_INPUT_MAP}.blue,${RAST_INPUT_MAP}.red,${RAST_INPUT_MAP}.green
    
####################################################################
# That's all, folks.

####################################################################
# Leftovers
 
# Input von Blue Marble:
#
# r.in.gdal -oel in=world.topo.bathy.200410.3x5400x2700.png out=world_col
# r.region n=90.0 s=-90.0 w=-180.0 e=180.0 map=world_col.green 
# r.colors map=world_col.green col=grey
# r.composite red=world_col.red green=world_col.green blue=world_col.blue out=world_col_grey

##############################################################
####### HOWTO

#Gore tweaking:
# -Ei[|*dpi*] -> DPI
# Sets the resolution of the projected grid that will be created if a map projection other than Linear or Mercator was selected [100]. 
# By default, the projected grid will be of the same size (rows and columns) as the input file. 
# Specify i to use the PostScript image operator to interpolate the image at the device resolution.

# -n[b|c|l|n][+a][+bBC][+c][+tthreshold]
# Select interpolation mode for grids.

# -t[transp]
# Set PDF transparency level in percent.


#psxy: -B[p|s]parameters
#-B[axes][+b][+gfill][+olon/lat][+ttitle]
#where axes selects which axes to plot. 
#By default, all 4 map boundaries (or plot axes) are plotted (named W, E, S, N). 
#To customize, append the codes for those you want (e.g., WSn). 
#Upper case means plot and annotate while lower case just plots the specified axes. 
