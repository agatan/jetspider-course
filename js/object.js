function MyObject(i) {
    this.index = i;
}
var first = new MyObject(one);
var second = new MyObject(two);
p(first.index);
p(second.index);
first.index = 3;
p("first.index = 3;");
p(first.index);
p(second.index);
p("increment...");
p(first.index++);
p(first.index);
