struct Style {
	size  int
	color int
}

struct Theme {
	b3 Style
}

struct A11yCfg {
	label string
	desc  string
}

struct View {
	tag int
}

@[minify]
struct TextCfg {
	A11yCfg
	text  string
	style Style
	f0 int
	f1 int
	f2 int
	f3 int
	f4 int
	f5 int
	f6 int
	f7 int
	f8 int
	f9 int
	f10 int
	f11 int
	f12 int
	f13 int
	f14 int
	f15 int
	f16 int
	f17 int
	f18 int
	f19 int
	f20 int
	f21 int
	f22 int
	f23 int
	f24 int
	f25 int
	f26 int
	f27 int
	f28 int
	f29 int
	f30 int
	f31 int
	f32 int
	f33 int
	f34 int
	f35 int
	f36 int
	f37 int
	f38 int
	f39 int
	f40 int
	f41 int
	f42 int
	f43 int
	f44 int
	f45 int
	f46 int
	f47 int
	f48 int
	f49 int
	f50 int
	f51 int
	f52 int
	f53 int
	f54 int
	f55 int
	f56 int
	f57 int
	f58 int
	f59 int
}

@[minify]
struct BoxCfg {
	A11yCfg
	id      int
	content []View
	action  fn (int) int = unsafe { nil }
	f0 int
	f1 int
	f2 int
	f3 int
	f4 int
	f5 int
	f6 int
	f7 int
	f8 int
	f9 int
	f10 int
	f11 int
	f12 int
	f13 int
	f14 int
	f15 int
	f16 int
	f17 int
	f18 int
	f19 int
	f20 int
	f21 int
	f22 int
	f23 int
	f24 int
	f25 int
	f26 int
	f27 int
	f28 int
	f29 int
	f30 int
	f31 int
	f32 int
	f33 int
	f34 int
	f35 int
	f36 int
	f37 int
	f38 int
	f39 int
	f40 int
	f41 int
	f42 int
	f43 int
	f44 int
	f45 int
	f46 int
	f47 int
	f48 int
	f49 int
	f50 int
	f51 int
	f52 int
	f53 int
	f54 int
	f55 int
	f56 int
	f57 int
	f58 int
	f59 int
}

fn theme() Theme {
	return Theme{ b3: Style{ size: 10, color: 1 } }
}

fn text(c TextCfg) View {
	return View{ tag: c.style.size }
}

fn box(c BoxCfg) View {
	return View{ tag: c.content.len + c.id }
}

fn main() {
	busy := false
	mut views := []View{}
	if busy {
		views << box(id: 1, content: [text(text: 'Cancel')])
	} else {
		views << box(
			id:      2
			content: [
				text(
					text:  'Scan'
					style: Style{
						...theme().b3
						color: 9
					}
				),
			]
			action:  fn (x int) int {
				return x
			}
		)
	}
	println(views)
}
