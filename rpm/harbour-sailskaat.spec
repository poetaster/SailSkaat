Name:       harbour-sailskaat
# >> macros
%define _binary_payload w2.xzdio
# << macros

%{!?qtc_qmake:%define qtc_qmake %qmake}
%{!?qtc_qmake5:%define qtc_qmake5 %qmake5}
%{!?qtc_make:%define qtc_make make}
%{?qtc_builddir:%define _builddir %qtc_builddir}

Summary:    Skaat Game
Version:    0.2.0
Release:    1
License:    GPLv3
BuildArch:  noarch
URL:        https://github.com/nikku/skaat-app
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   libsailfishapp-launcher
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.3
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
Three player Skaat. You Vs. two bots. Native QML game with the Skat rules
engine from https://github.com/nikku/skaat embedded as a QML JavaScript library.

%if "%{?vendor}" == "chum"
PackageName: SailSkaat
Type: desktop-application
Categories:
 - Game
PackagerName: Mark Washeim
Custom:
 - RepoType: github
 - Repo: https://github.com/poetaster/SailSkaat
Icon: https://raw.githubusercontent.com/poetaster/SailSkaat/main/icons/172x172/harbour-sailskaat.png
Screenshots:
 - https://raw.githubusercontent.com/poetaster/SailSkaat/main/Screenshot_20260331_175049_001.png
 - https://raw.githubusercontent.com/poetaster/SailSkaat/main/Screenshot_20260331_175044_001.png
 - https://raw.githubusercontent.com/poetaster/SailSkaat/main/Screenshot_20260331_175010_001.png
Url:
  Homepage: https://github.com/poetaster/SailSkaat
  Bugtracker: https://github.com/poetaster/SailSkaat/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build

%qmake5 

%make_build


%install
%qmake5_install

desktop-file-install --delete-original       \
  --dir %{buildroot}%{_datadir}/applications             \
   %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_datadir}/%{name}
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/applications/%{name}.desktop
%{_datadir}/%{name}/qml
