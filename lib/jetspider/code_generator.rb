require 'jetspider/ast'
require 'jetspider/exception'

module JetSpider
  class CodeGenerator < AstVisitor
    def initialize(object_file)
      @object_file = object_file
      @asm = nil
      @loop_locations = []
    end

    def generate_object_file(ast)
      @compiling_toplevel = false
      ast.global_functions.each do |fun|
        compile_function fun
      end
      compile_toplevel ast
      @object_file
    end

    def compile_function(fun)
      open_asm_writer(fun.scope, fun.filename, fun.lineno) {
        visit fun.function_body.value
      }
    end

    def compile_toplevel(ast)
      open_asm_writer(ast.global_scope, ast.filename, ast.lineno) {
        @compiling_toplevel = true
        traverse_ast(ast)
        @compiling_toplevel = false
      }
    end

    def open_asm_writer(*unit_args)
      unit = @object_file.new_unit(*unit_args)
      @asm = Assembler.new(unit)
      yield
      @asm.stop
    ensure
      @asm = nil
    end

    #
    # Declarations & Statements
    #

    def visit_SourceElementsNode(node)
      node.value.each do |n|
        visit n
      end
    end

    def visit_ExpressionStatementNode(node)
      visit node.value
      pop_statement_value
    end

    def pop_statement_value
      if @compiling_toplevel
        @asm.popv
      else
        @asm.pop
      end
    end

    def visit_EmptyStatementNode(n)
      # We can silently remove
    end

    def visit_BlockNode(n)
      visit n.value
    end

    def visit_CommaNode(n)
      visit n.left
      @asm.pop
      visit n.value
    end

    #
    # Functions-related
    #

    def visit_FunctionCallNode(n)
      if n.value.class == RKelly::Nodes::DotAccessorNode
        visit n.value.value
        @asm.callprop(n.value.accessor)
      elsif n.value.class == RKelly::Nodes::BracketAccessorNode
        visit n.value.value
        visit n.value.accessor
        @asm.callelem
      else
        @asm.callgname(n.value.value)
      end
      n.arguments.value.each do |arg|
        visit arg
      end
      @asm.call(n.arguments.value.count)
    end

    def visit_FunctionDeclNode(n)
      unless @compiling_toplevel
        raise SemanticError, "nested function not implemented yet"
      end
      # Function declarations are compiled in other step,
      # we just ignore them while compiling toplevel.
    end

    def visit_FunctionExprNode(n) raise "FunctionExprNode not implemented"; end

    def visit_ReturnNode(n)
      visit n.value
      @asm.return
    end

    # These nodes should not be visited directly
    def visit_ArgumentsNode(n) raise "[FATAL] ArgumentsNode visited"; end
    def visit_FunctionBodyNode(n) raise "[FATAL] FunctionBodyNode visited"; end
    def visit_ParameterNode(n) raise "[FATAL] ParameterNode visited"; end

    #
    # Variables-related
    #

    def visit_ResolveNode(n)
      getvar(n)
    end

    def visit_OpEqualNode(n)
      setvar(n.left) { visit n.value }
    end

    def visit_VarStatementNode(n)
      n.value.each do |decl|
        visit decl
      end
    end

    def visit_VarDeclNode(n)
      setvar(n) { visit n.value.value }
      @asm.pop
    end

    def visit_AssignExprNode(n)
      raise NotImplementedError, 'AssignExprNode'
    end

    # We do not support let, const, with
    def visit_ConstStatementNode(n) raise "ConstStatementNode not implemented"; end
    def visit_WithNode(n) raise "WithNode not implemented"; end

    def visit_OpPlusEqualNode(n) raise "OpPlusEqualNode not implemented"; end
    def visit_OpMinusEqualNode(n) raise "OpMinusEqualNode not implemented"; end
    def visit_OpMultiplyEqualNode(n) raise "OpMultiplyEqualNode not implemented"; end
    def visit_OpDivideEqualNode(n) raise "OpDivideEqualNode not implemented"; end
    def visit_OpModEqualNode(n) raise "OpModEqualNode not implemented"; end
    def visit_OpAndEqualNode(n) raise "OpAndEqualNode not implemented"; end
    def visit_OpOrEqualNode(n) raise "OpOrEqualNode not implemented"; end
    def visit_OpXOrEqualNode(n) raise "OpXOrEqualNode not implemented"; end
    def visit_OpLShiftEqualNode(n) raise "OpLShiftEqualNode not implemented"; end
    def visit_OpRShiftEqualNode(n) raise "OpRShiftEqualNode not implemented"; end
    def visit_OpURShiftEqualNode(n) raise "OpURShiftEqualNode not implemented"; end

    #
    # Control Structures
    #

    def visit_IfNode(n)
      visit n.conditions
      else_loc = @asm.lazy_location
      merge_loc = @asm.lazy_location
      @asm.ifeq(else_loc)
      visit n.value
      @asm.goto(merge_loc)
      @asm.fix_location(else_loc)
      if n.else
        visit n.else
      end
      @asm.fix_location(merge_loc)
    end

    def visit_ConditionalNode(n)
      visit n.conditions
      else_loc = @asm.lazy_location
      merge_loc = @asm.lazy_location
      @asm.ifeq(else_loc)
      visit n.value
      @asm.goto(merge_loc)
      @asm.fix_location(else_loc)
      visit n.else
      @asm.fix_location(merge_loc)
    end

    def visit_WhileNode(n)
      exit_loc = @asm.lazy_location
      loop_loc = @asm.location
      @loop_locations.push({loop: loop_loc, exit: exit_loc})
      visit n.left
      @asm.ifeq exit_loc
      n.value.value.value.each do |s|
        visit s
      end
      @asm.goto loop_loc
      @asm.fix_location(exit_loc)
      @loop_locations.pop
    end

    def visit_DoWhileNode(n)
      raise NotImplementedError, 'DoWhileNode'
    end

    def visit_ForNode(n)
      visit n.init
      body_loc = @asm.lazy_location
      @asm.goto body_loc
      loop_loc = @asm.location
      visit n.counter
      @asm.pop
      exit_loc = @asm.lazy_location
      @loop_locations.push({loop: loop_loc, exit: exit_loc})
      @asm.fix_location body_loc
      visit n.test
      @asm.ifeq exit_loc
      visit n.value
      @asm.goto loop_loc
      @asm.fix_location exit_loc
      @loop_locations.pop
    end

    def visit_BreakNode(n)
      @asm.goto @loop_locations.last[:exit]
    end

    def visit_ContinueNode(n)
      @asm.goto @loop_locations.last[:loop]
    end

    def visit_SwitchNode(n) raise "SwitchNode not implemented"; end
    def visit_CaseClauseNode(n) raise "CaseClauseNode not implemented"; end
    def visit_CaseBlockNode(n) raise "CaseBlockNode not implemented"; end

    def visit_ForInNode(n) raise "ForInNode not implemented"; end
    def visit_InNode(n) raise "InNode not implemented"; end
    def visit_LabelNode(n) raise "LabelNode not implemented"; end

    # We do not support exceptions
    def visit_TryNode(n) raise "TryNode not implemented"; end
    def visit_ThrowNode(n) raise "ThrowNode not implemented"; end

    #
    # Compound Expressions
    #

    def visit_ParentheticalNode(n)
      visit n.value
    end

    def constant_fold(node)
      return node if node.class != RKelly::Nodes::AddNode
      lhs = constant_fold node.left
      rhs = constant_fold node.value
      if lhs.class == RKelly::Nodes::NumberNode and rhs.class == RKelly::Nodes::NumberNode
        RKelly::Nodes::NumberNode.new(lhs.value + rhs.value)
      else
        RKelly::Nodes::AddNode.new(lhs, rhs)
      end
    end

    def visit_AddNode(n)
      n = constant_fold n
      if n.class == RKelly::Nodes::AddNode
        visit n.left
        visit n.value
        @asm.add
      else
        visit n
      end
    end

    def visit_SubtractNode(n)
      visit n.left
      visit n.value
      @asm.sub
    end

    def self.simple_binary_op(node_class, insn_name)
      define_method(:"visit_#{node_class}") {|node|
        visit node.left
        visit node.value
        @asm.__send__(insn_name)
      }
    end

    simple_binary_op 'MultiplyNode', :mul
    simple_binary_op 'DivideNode', :div
    simple_binary_op 'ModulusNode', :mod

    def visit_UnaryPlusNode(n)
      raise NotImplementedError, 'UnaryPlusNode'
    end

    def visit_UnaryMinusNode(n)
      raise NotImplementedError, 'UnaryMinusNode'
    end

    def visit_PrefixNode(n)
      raise "PrefixNode not implemented"
    end

    def visit_PostfixNode(n)
      raise "'#{n.value}' is not supported..." if n.value != "++"
      if n.operand.class == RKelly::Nodes::DotAccessorNode
        prop_inc(n.operand)
        return
      elsif n.operand.class == RKelly::Nodes::BracketAccessorNode
        bracket_inc(n.operand)
        return
      end
      operand = n.operand
      if operand.variable.global?
        global_inc(n)
      elsif operand.variable.local? or operand.variable.parameter?
        variable_inc(n)
      else
        raise "attribute is not supported yet..."
      end
    end

    def visit_BitwiseNotNode(n) raise "BitwiseNotNode not implemented"; end
    def visit_BitAndNode(n) raise "BitAndNode not implemented"; end
    def visit_BitOrNode(n) raise "BitOrNode not implemented"; end
    def visit_BitXOrNode(n) raise "BitXOrNode not implemented"; end
    def visit_LeftShiftNode(n) raise "LeftShiftNode not implemented"; end
    def visit_RightShiftNode(n) raise "RightShiftNode not implemented"; end
    def visit_UnsignedRightShiftNode(n) raise "UnsignedRightShiftNode not implemented"; end

    def visit_TypeOfNode(n) raise "TypeOfNode not implemented"; end

    #
    # Comparison
    #

    simple_binary_op 'EqualNode', :eq
    simple_binary_op 'NotEqualNode', :ne
    simple_binary_op 'StrictEqualNode', :stricteq
    simple_binary_op 'NotStrictEqualNode', :strictne

    simple_binary_op 'GreaterNode', :gt
    simple_binary_op 'GreaterOrEqualNode', :ge
    simple_binary_op 'LessNode', :lt
    simple_binary_op 'LessOrEqualNode', :le

    simple_binary_op 'LogicalAndNode', :and
    simple_binary_op 'LogicalOrNode', :or

    def visit_LogicalNotNode(n)
      visit n.value
      @asm.not
    end

    #
    # Object-related
    #

    def visit_NewExprNode(n)
      getvar(n.value)
      @asm.push
      n.arguments.value.each do |arg|
        visit arg
      end
      @asm.new(n.arguments.value.count)
    end

    def visit_DotAccessorNode(n)
      visit n.value
      @asm.getprop(n.accessor)
    end

    def visit_BracketAccessorNode(n)
      visit n.value
      visit n.accessor
      @asm.getelem
    end

    def visit_InstanceOfNode(n) raise "InstanceOfNode not implemented"; end
    def visit_AttrNode(n) raise "AttrNode not implemented"; end
    def visit_DeleteNode(n) raise "DeleteNode not implemented"; end
    def visit_PropertyNode(n) raise "PropertyNode not implemented"; end
    def visit_GetterPropertyNode(n) raise "GetterPropertyNode not implemented"; end
    def visit_SetterPropertyNode(n) raise "SetterPropertyNode not implemented"; end

    #
    # Primitive Expressions
    #

    def visit_NullNode(n)
      @asm.null
    end

    def visit_TrueNode(n)
      @asm.true
    end

    def visit_FalseNode(n)
      @asm.false
    end

    def visit_ThisNode(n)
      @asm.this
    end

    def visit_NumberNode(n)
      if n.value == 1
        @asm.one
      elsif -128 <= n.value and n.value < 128
        @asm.int8(n.value)
      elsif 0 <= n.value and n.value < 65536
        @asm.uint16(n.value)
      elsif 0 <= n.value and n.value < 16777216
        @asm.uint24(n.value)
      elsif -2147483648 <= n.value and n.value < 2147483648 
        @asm.int32(n.value)
      else
        raise "NumberNode value is too big..."
      end
    end

    def visit_StringNode(n)
      @asm.string(eval(n.value))
    end

    def visit_ArrayNode(n)
      @asm.newarray(n.value.count)
      n.value.each_with_index do |elem, idx|
        visit RKelly::Nodes::NumberNode.new(idx)
        visit elem.value
        @asm.initelem
      end
      @asm.endinit
    end

    def visit_ElementNode(n) raise "ElementNode not implemented"; end

    def visit_RegexpNode(n) raise "RegexpNode not implemented"; end

    def visit_ObjectLiteralNode(n) raise "ObjectLiteralNode not implemented"; end

    def visit_VoidNode(n) raise "VoidNode not implemented"; end

  private
    def getvar(n)
      var = n.variable
      case
      when var.parameter?
        @asm.getarg var.index
      when var.local?
        @asm.getlocal var.index
      when var.global?
        # @asm.bindgname var.name
        @asm.getgname var.name
      else
        raise "[FATAL] unsupported variable type for dereference: #{var.inspect}"
      end
    end

    def setvar(n, &blk)
      if n.class == RKelly::Nodes::DotAccessorNode
        setprop(n) { blk.call if blk }
        return
      elsif n.class == RKelly::Nodes::BracketAccessorNode
        setelem(n) { blk.call if blk }
        return
      end
      var = n.variable
      case
      when var.parameter?
        blk.call if blk
        @asm.setarg var.index
      when var.local?
        blk.call if blk
        @asm.setlocal var.index
      when var.global?
        @asm.bindgname var.name
        blk.call if blk
        @asm.setgname var.name
      else
        raise "[FATAL] unsupported variable type for dereference: #{var.inspect}"
      end
    end

    def setprop(n, &blk)
      visit n.value
      blk.call if blk
      @asm.setprop n.accessor
    end

    def setelem(n, &blk)
      visit n.value
      visit n.accessor
      blk.call if blk
      @asm.setelem
    end

    def global_inc(n)
      getvar(n.operand)
      @asm.bindgname(n.operand.variable.name)
      getvar(n.operand)
      @asm.one
      @asm.add
      @asm.setgname(n.operand.variable.name)
      @asm.pop
    end
    
    def variable_inc(n)
      getvar(n.operand)
      getvar(n.operand)
      @asm.one
      @asm.add
      setvar(n.operand)
      @asm.pop
    end

    def prop_inc(n)
      visit n.value
      @asm.dup
      @asm.getprop n.accessor
      @asm.one
      @asm.add
      @asm.setprop n.accessor
      @asm.one
      @asm.sub
    end

    def bracket_inc(n)
      visit n.value
      visit n.accessor
      @asm.eleminc
    end
  end
end
