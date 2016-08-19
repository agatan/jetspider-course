var global = 2;

function f() {
    var x = 0;
    p(x++);
    p(x);
}

f();
p(global++);
p(global);
