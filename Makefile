version:
	npx asciidoctor-revealjs --version
convert:
	#asciidoctor-revealjs -r asciidoctor-diagram -a revealjs_theme=solarized-dark -a revealjs_transition=fade -a revealjs_slideNumber=true -a revealjs_center=true -a revealjs_progress=true -a revealjs_controls=true -a revealjs_history=true -a revealjs_overview=true -a revealjs_loop=false -a revealjs_keyboard=true -a toc=left -a toclevels=3 -D docs slides.adoc
	#asciidoctor-revealjs -r asciidoctor-diagram -a revealjs_theme=solarized-dark -a revealjs_transition=fade -a revealjs_slideNumber=true -a revealjs_center=true -a revealjs_progress=true -a revealjs_controls=true -a revealjs_history=true -a revealjs_overview=true -a revealjs_loop=false -a revealjs_keyboard=true -a toc=left -a toclevels=3 -D html/ mcp-server.adoc
	./asciidoctor-revealjs mcp-servers.adoc
	./asciidoctor-revealjs mcp-servers2.adoc