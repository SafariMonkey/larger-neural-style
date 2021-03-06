#! /bin/bash

main(){
	# 1. defines
	input=$1
	input_file=`basename $input`
	clean_name="${input_file%.*}"
	
	style=$2
	style_dir=`dirname $style`
	style_file=`basename $style`
	style_name="${style_file%.*}"
	
	output="./output"
	out_file=$output/$input_file
	
	# 2. neural-style the original input
	if [ ! -s $out_file ] ; then
		neural_style $input $style $out_file
	fi
  #convert $input -resize 1000x1000 $out_file #juse resize
	
	w1=`convert $out_file -format "%w" info:`
	h1=`convert $out_file -format "%h" info:`
	
	# 3. tile it
	out_dir=$output/$clean_name
	mkdir -p $out_dir
	convert $out_file -crop 3x3+20+20@ +repage +adjoin $out_dir/$clean_name"_%d.jpg"
	# tile style
	#convert $style -crop 3x3+20+20@ +repage +adjoin $style_dir/$style_name"_%d.jpg"
	
	w2=`convert $out_dir/$clean_name'_0.jpg' -format "%w" info:`
	h2=`convert $out_dir/$clean_name'_0.jpg' -format "%h" info:`
	w_percent=`echo 20 $w2 | awk '{print $1/$2}'`
	h_percent=`echo 20 $h2 | awk '{print $1/$2}'`

	border_w=`echo $w1 $w_percent | awk '{print $1*$2}'`
	border_h=`echo $h1 $h_percent | awk '{print $1*$2}'`
	
	# 4. neural-style each tile
	tiles_dir="$out_dir/tiles"
	mkdir -p $tiles_dir
	for tile in `ls $out_dir | grep $clean_name"_"[0-9]".jpg"`
	do
		#for i in $( seq 0 8 ); do
		#	neural_style $out_dir/$clean_name"_$i.jpg" $style_dir/$style_name"_$i.jpg" $tiles_dir/$clean_name"_$i.jpg"
		#done
		neural_style $out_dir/$tile $style $tiles_dir/$tile
	done
	
	# 5. feather tiles
	feathered_dir=$out_dir/feathered
	mkdir -p $feathered_dir
	for tile in `ls $tiles_dir | grep $clean_name"_"[0-9]".jpg"`
	do
		tile_name="${tile%.*}"
		convert $tiles_dir/$tile -alpha set -virtual-pixel transparent -channel A -morphology Distance Euclidean:1,50\! +channel "$feathered_dir/$tile_name.png"
	done
	
	# 6. merge feathered tiles
	montage $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' \
					$feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' \
					$feathered_dir/$clean_name'_4.png' $feathered_dir/$clean_name'_5.png' \
					$feathered_dir/$clean_name'_6.png' $feathered_dir/$clean_name'_7.png' \
					$feathered_dir/$clean_name'_8.png'  -tile 3x3 -geometry -$border_w-$border_h $output/$clean_name.large.jpg
}
retry=0
neural_style(){
	echo "Neural Style Transfering "$1
	if [ ! -s $3 ]; then
		th neural_style.lua -content_image $1 -style_image $2 -output_image $3 \
				-image_size 1000 -print_iter 100 -backend cudnn -gpu 0 -save_iter 0 \
				-style_weight 20 -num_iterations 500
				#-original_colors 1
	fi
	if [ ! -s $3 ] && [ $retry -lt 3 ] ;then
			echo "Transfer Failed, Retrying for $retry time(s)"
			retry=`echo 1 $retry | awk '{print $1+$2}'`
			neural_style $1 $2 $3
	fi
	retry=0
}

main $1 $2 $3
