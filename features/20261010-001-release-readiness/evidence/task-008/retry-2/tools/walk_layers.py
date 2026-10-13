# lldb python: 지정 창(_NSPopoverWindow)의 contentView.superview 루트 layer부터 sublayer를 따라가며
# contents가 있는 layer의 클래스·크기·contents 클래스를 출력한다.
import lldb
def ev(f, e):
    v = f.EvaluateExpression(e, opts)
    return v
def run(debugger, command, result, internal):
    global opts
    t = debugger.GetSelectedTarget(); f = t.GetProcess().GetSelectedThread().GetSelectedFrame()
    opts = lldb.SBExpressionOptions(); opts.SetLanguage(lldb.eLanguageTypeObjC); opts.SetTimeoutInMicroSeconds(5000000)
    root = ev(f, "(id)[[[[[[NSApplication sharedApplication] windows] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@\"className == '_NSPopoverWindow'\"]] firstObject] contentView] superview] layer]").GetValueAsUnsigned()
    stack = [(root, 0)]; n = 0; withc = 0
    while stack:
        a, d = stack.pop(); n += 1
        cls = ev(f, "(const char*)object_getClassName((id)%d)" % a).GetSummary()
        b = ev(f, "(CGRect)[(CALayer*)%d bounds]" % a)
        w = b.GetChildMemberWithName('size').GetChildMemberWithName('width').GetValue(); h = b.GetChildMemberWithName('size').GetChildMemberWithName('height').GetValue()
        c = ev(f, "(id)[(CALayer*)%d contents]" % a).GetValueAsUnsigned()
        cc = ev(f, "(const char*)object_getClassName((id)%d)" % c).GetSummary() if c else ''
        hidden = ev(f, "(BOOL)[(CALayer*)%d isHidden]" % a).GetValueAsUnsigned()
        if c: withc += 1
        if c or d < 3:
            print("%s%s %sx%s contents=%s hidden=%d" % ('  ' * d, cls, w, h, cc, hidden))
        cnt = ev(f, "(long)[[(CALayer*)%d sublayers] count]" % a).GetValueAsUnsigned()
        for i in range(cnt):
            s = ev(f, "(id)[[(CALayer*)%d sublayers] objectAtIndex:%d]" % (a, i)).GetValueAsUnsigned()
            stack.append((s, d + 1))
    print("layers=%d withContents=%d" % (n, withc))
def __lldb_init_module(debugger, internal):
    debugger.HandleCommand('command script add -f walk_layers.run walk_layers')
