PROJECT_NAME = antimike-fzf-scripts
PROJECT_DIR = `pwd`
VERSION = 0.0.1

LINKS = wifi
INSTALL_FILES = $(foreach link, $(LINKS), $(shell find -executable -name "*$(link)*.sh" | head -1))
DEST_DIR = /usr/local/bin
ARCHIVE = $(PROJECT_NAME).tar.gz
SIG = $(PROJECT_NAME).asc

.PHONY : build sign clean tag release install uninstall all

$(ARCHIVE) :
	git archive --output=$(ARCHIVE) --prefix="$(PROJECT_DIR)/" HEAD

build : $(ARCHIVE)

sign : $(ARCHIVE)
	gpg --sign --detach-sign --armor "$(ARCHIVE)"

clean :
	rm -f "$(ARCHIVE)" "$(SIG)"

all :
	$(ARCHIVE) $(SIG)

tag :
	git tag v$(VERSION)
	git push --tags

release : $(ARCHIVE) $(SIG) tag

install :
	for link in $(LINKS); do \
		sudo ln -s "`realpath $$(find -executable -name "*$${link}*.sh" -type f)`" "$(DEST_DIR)/$${link}"; \
	done

uninstall :
	for link in $(LINKS); do sudo rm -f "$(DEST_DIR)/$${link}"; done
