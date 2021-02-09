decode_dir=/mnt/shareEx/xxr/uaspeech/hybrid255_dnn_wd_res_small2
DNN_dir=/mnt/shareEx/xxr/uaspeech/dnn_wd_res_small2/all
nnet=final.nnet
tool_dir=/project/bdda/skhu/Download/kaldi-trunk-new/egs/uaspeech/s5/utils_decode
scripts_dir=scripts
kaldi_hmm_dir=/project/bdda/skhu/Download/kaldi-trunk-new/egs/uaspeech/s5/model_kaldi
openfst_dir=/project/bdda/skhu/Download/kaldi-trunk-new/tools/openfst-1.3.4/bin
num_job=50
max_active=10500
acwt=0.1
#scp_file=test_adpv_bag_win21_pma_state_sort_kaldi.scp
#scp_file=test_adpv_bag_win21_pma_mono_nosp_sort_kaldi.scp
#scp_file=test_adpv_bag_win21_pma_word_sort_kaldi.scp
scp_file=test_testcv_problem_kaldi.scp
pdf_file=
prior_counts=ali_train_pdf.counts
trans_mdl=
ref_mlf_file=decode/test.mlf
mlist_file=hmms.mlist
conf_file=decode_dnn.config
no_softmax=false
use_gpu=no

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

mkdir -p ${decode_dir}/lattices

ln -s ${DNN_dir}/$nnet ${decode_dir}/final.nnet
ln -s ${DNN_dir}/final.feature_transform ${decode_dir}/final.feature_transform
ln -s ${kaldi_hmm_dir}/tree ${decode_dir}/tree

if [ -z "$prior_counts" ]; then
	analyze-counts --binary=false ark:${pdf_file}  ${decode_dir}/ali_train_pdf.counts
	prior_counts=${decode_dir}/ali_train_pdf.counts
fi

if [ -z "$trans_mdl" ]; then
	copy-transition-model --binary=false ${kaldi_hmm_dir}/final.mdl ${decode_dir}/final.mdl
else
	cp $trans_mdl ${decode_dir}/final.mdl
fi

apply_log=false
if [ "$no_softmax" != "true" ]; then
	apply_log=true
	no_softmax=false
fi

cp ${scp_file} ${decode_dir}/feats.scp
cp ${conf_file} ${decode_dir}/decode_dnn.config

export PATH=${tool_dir}/:$PATH

bash ${scripts_dir}/decode_hybrid_newv.sh --apply-log $apply_log --no-softmax $no_softmax --nj ${num_job} --class-frame-counts $prior_counts --max_active ${max_active} --acwt ${acwt} --use_gpu_id $use_gpu --config ${decode_dir}/decode_dnn.config ${kaldi_hmm_dir} ${decode_dir} ${decode_dir}/decode

cat ${decode_dir}/decode/*.tra > ${decode_dir}/decode/test.tra
cat ${decode_dir}/decode/*.ali > ${decode_dir}/decode/test.ali

rm -r ${decode_dir}/decode/test.*.tra
rm -r ${decode_dir}/decode/test.*.ali

perl ${scripts_dir}/id2work.pl ${decode_dir}/decode/test.tra ${kaldi_hmm_dir}/words.txt > ${decode_dir}/decode/test_trans.txt

perl ${scripts_dir}/K_txt2mlf.pl ${decode_dir}/decode/test_trans.txt > ${decode_dir}/decode/test_trans.mlf

HResults -h -t -I ${ref_mlf_file} ${mlist_file} ${decode_dir}/decode/test_trans.mlf > ${decode_dir}/decode/test_WER.list
