# source necessary files
source /opt/share/etc/gcc-5.4.0.sh
source  /project_bdda3/bdda/mengzhe/DataAugmentation/kaldi-trunk-new/egs/uaspeech/s5/kaldi_path.sh

EXP_PATH=/project_bdda4/bdda/zrjin/DA_AL/SI_SYS/${1}
LOG_PATH=$EXP_PATH/log

PROTOS_PATH=/project_bdda4/bdda/zrjin/PROTOS
SCRIPTS_PATH=/project_bdda4/bdda/zrjin/jzr_nnet
readonly EXP_PATH PROTOS_PATH SCRIPTS_PATH
source $SCRIPTS_PATH/path.sh
source $SCRIPTS_PATH/conf.sh

mkdir -p $EXP_PATH
mkdir -p $LOG_PATH


cd $EXP_PATH

# start constructing nnet structure
mkdir -p nnet_structures
mkdir -p nnet_components

cp $PROTOS_PATH/nnet/protos/* nnet_components
cp -r $PROTOS_PATH/nnet/l* nnet_components

C=nnet_components
S=nnet_structures

echo "<CopyN> 4000 2000 2" >\
    $C/copy2_2000.nnet
echo "<SumN> 2000 4000 2 1.0" >\
    $C/sum2_2000.nnet
echo "<Rescale> <InputDim> 2000 <OutputDim> 2000 <InitParam> 0.0 <LearnRateCoef> 1.0" >\
    $C/Rescale.proto

nnet-initialize --binary=false $C/Rescale.proto $C/Rescale.nnet

nnet-concat \
    $C/l2/final_notop.nnet \
    $C/l3/final_notop.nnet \
    ${C}/final_notop_l2l3.nnet
nnet-concat \
    $C/l5/final_notop.nnet \
    $C/l6/final_notop.nnet \
    ${C}/final_notop_l5l6.nnet

cat $PROTOS_PATH/nnet/protos/parallel_net.proto \
    | sed "s/dim_in/4000/g" \
    | sed "s/dim_out/4000/g" \
    | sed "s/nnet1/${C}\/final_notop_l2l3.nnet/g" \
    | sed "s/nnet2/${C}\/Rescale.nnet/g" \
    > $C/parallel_net.proto

nnet-initialize $C/parallel_net.proto - | \
    nnet-concat $C/copy2_2000.nnet - $C/sum2_2000.nnet $C/final_notop_l2l3_skip.nnet

cat $PROTOS_PATH/nnet/protos/parallel_net.proto \
    | sed "s/dim_in/4000/g" \
    | sed "s/dim_out/4000/g" \
    | sed "s/nnet1/${C}\/final_notop_l5l6.nnet/g" \
    | sed "s/nnet2/${C}\/Rescale.nnet/g" \
    > $C/parallel_net.proto

nnet-initialize $C/parallel_net.proto - | \
    nnet-concat $C/copy2_2000.nnet - $C/sum2_2000.nnet $C/final_notop_l5l6_skip.nnet

nnet-copy --remove-last-components=2 \
    $C/l7/final.nnet \
    $C/DNN7_notop.nnet
nnet-copy --remove-first-components=3 \
    $C/l7/final.nnet \
    $C/DNN7_top.nnet

python $SCRIPTS_PATH/utils/make_nnet_proto.py --param-stddev-factor=0.0 100 41 0 2000 \
    | sed "s/<AffineTransform>/<AffineTransformRMSProp>/g" \
    | sed "s/<BiasMean>/<BiasLearnRateCoef> 0.100000 <ClipWeightUpdate> 0.16 <ClipBiasUpdate> 0.16 <BiasMean>/g" \
    > $C/top_mono.proto
nnet-initialize --binary=false \
    $C/top_mono.proto \
    $C/top_mono.nnet

cat $PROTOS_PATH/nnet/protos/parallel_net.proto \
    | sed "s/dim_in/200/g" \
    | sed "s/dim_out/2042/g" \
    | sed "s/nnet1/${C}\/top_mono.nnet/g" \
    | sed "s/nnet2/${C}\/DNN7_top.nnet/g" \
    > $C/parallel_top.proto
echo "<CopyN> 200 100 2" \
    > $C/Copy100_2.nnet

nnet-initialize \
    $C/parallel_top.proto - \
    | nnet-concat $C/DNN7_notop.nnet $C/Copy100_2.nnet - \
        $C/DNN7_MTL.nnet

nnet-concat \
    --binary=false \
    $C/l1/final_notop.nnet \
    $C/final_notop_l2l3_skip.nnet \
    $C/l4/final_notop.nnet \
    $C/final_notop_l5l6_skip.nnet \
    $C/DNN7_MTL.nnet \
    $S/nnet.init

train_scp=$SCP_PATH/train.scp
cv_scp=$SCP_PATH/cv.scp
train_label=$LABEL_PATH/train.post
cv_label=$LABEL_PATH/cv.post
dbn_dir=$DBN_PATH
mlp_dir=$MLP_PATH
label_num=$LABEL_NUM

bash mlp_train_label.sh \
    --mlp_init $mlp_dir/nnet.init \
    --learn-rate 0.002 \
    --copy-feats false \
    --objective-function 'multitask,xent,41,0.5,xent,2001,0.5' \
    --train-opts '--max-iters 0 --max-iters-fix 8 --max-iters-dec 7 --decay-factor 0.5 --momentum 0.5 --l2_penalty 0.0000025 --pre_eval true' \
    --feature-transform context9_80.transf \
    $mlp_dir \
    $train_scp \
    $cv_scp \
    $train_label \
    $cv_label \
    $label_num \
    >& $LOG_PATH/dnn_all.log

# ???
mv \
    $mlp_dir/final.nnet \
    $mlp_dir/final_MTL.nnet

nnet-copy \
    --remove-last-components=2 \
    --binary=false \
    $mlp_dir/final_MTL.nnet \
    $mlp_dir/final_notop.nnet

nnet-copy \
    --remove-first-components=19 \
    --binary=false \
    $mlp_dir/final_MTL.nnet \
    $mlp_dir/final_top_MTL.nnet

perl \
    $SCRIPTS_PATH/scripts/MTL_keep_the_N.pl \
    $mlp_dir/final_top_MTL.nnet \
    2 \
    > $mlp_dir/final_top.nnet

nnet-concat \
    --binary=false \
    $mlp_dir/final_notop.nnet \
    $mlp_dir/final_top.nnet \
    $mlp_dir/final.nnet

bash decode.sh \
    --scp-file /project_bdda3/bdda/mengzhe/DataAugmentation/kaldi-trunk-new/egs/uaspeech/s5/test_testcv_fbk_problem_kaldi.scp \
    --decode-dir /project_bdda3/bdda/mengzhe/DataAugmentation/kaldi-trunk-new/egs/uaspeech/s5/hybrid255_dnn_fbk_wd_batchnorm_new_rmsprop_all_dropout_res_MTL_mono0505_fix8decay7_bdda4 \
    --DNN-dir /project_bdda3/bdda/mengzhe/DataAugmentation/kaldi-trunk-new/egs/uaspeech/s5/dnn_fbk_wd_batchnorm_new_rmsprop/all_dropout_res_MTL_mono0505_fix8decay7_bdda4 \
    --prior_counts /project_bdda3/bdda/mengzhe/DataAugmentation/kaldi-trunk-new/egs/uaspeech/s5/ali_train_pdf.counts


