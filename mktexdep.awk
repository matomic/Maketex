#function print_file(f) { system(sprintf("printf \"%s \"",f)); }
function print_exist(f) { system(sprintf("[ -f %s ] && printf \"%s \"",f,f)); }
#function print_eps(f) { system(sprintf("f=figures/%s; [ -f ${f} ] && printf \"${f} ${f%%eps}pdf \"",f)); }
function add_file(f) { if (system("test -f "f) == 0 ) {ARGV[ARGC]=f; ARGC++;} }
FNR==1 {printf("%s ",FILENAME)}
/^[^%]*\\inpu(t|t\[[^{}]*\]){[^{}]*}/ {
	split($0,A,/(.*\\inpu(t|t\[[^{}]*\]){|})/);
	add_file(A[2]); add_file(A[2]".tex");
}
/^[^%]*\\includ(e|e\[[^{}]*\]){[^{}]*}/ {
	split($0,A,/(.*\\includ(e|e\[[^{}]*\]){|})/);
	add_file(A[2]); add_file(A[2]".tex");
}
/^[^%]*\\documentclas(s|s\[[^{}]*\]){[^{}]*}/ {
	split($0,A,/(.*\\documentclas(s|s\[[^{}]*\]){|})/);
	print_exist(A[2]); print_exist(A[2]".cls");
}
/^[^%]*\\includegraphic(s|s\[[^{}]*\]){[^{}]*}/ {
	split($0,A,/(.*\\includegraphic(s|s\[[^{}]*\]){|})/);
	split(sprintf("%s %s.png %s.jpg %s.jpeg %s.eps %s.pdf",
		  A[2],A[2],A[2],A[2],A[2],A[2]), figs);
	for (ii in figs){
		print_exist(figs[ii])
#		print_exist("figures/"figs[ii])
	}
}
/^[^%]*\\bibliographystyle[^{}]*{[^{}]*}/ {
	split($0,A,/(.*\\bibliographystyle[^{}]*{|})/);
	print_exist(A[2]); print_exist(A[2]".bst");
}
/^[^%]*\\bibliograph(y|y\[[^{}]*\]){[^{}]*}/ {
	split($0,A,/(.*\\bibliography[^{}]*{|})/);
	printf(A[2]".bib ");
}
END{printf"\n"}
