function l() {
    var x = 0;
    p("LOCAL");
    p(x++);
    p(x);
}
l();

var global = 2;
p("GLOBAL");
p(global++);
p(global);

function param(x) {
    p("PARAMETER");
    p(x++);
    p(x);
}
param(4);

