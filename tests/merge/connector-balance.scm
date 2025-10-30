;
; connector-balance.scm
; Unit test for merging of Connectors - detailed balance.
;
; Tests merging of several words into a single word-class.
; The focus here is to make sure that detailed balance of the counts
; across the merged Sections and CrossSections are preserved (obeyed).
;
; Created Dec 2021

(use-modules (opencog) (opencog matrix))
(use-modules (opencog lg))
(use-modules (opencog learn))

(use-modules (opencog test-runner))
(use-modules (srfi srfi-64))

(opencog-test-runner)

(load "connector-setup.scm")
(load "balance-data.scm")

; ---------------------------------------------------------------
;
; This diagram explains what is being tested here:
;
;    (a, gh) + (b, gh) -> ({ab}, gh)
;    (c, kaaam)        -> (c, k{ab}{ab}{ab}m)
;
; In this diagram, (e,abc) is abbreviated notation for
; (Section (Word e) (ConnectorList (Connector a) (Connector b) (Connector c)))
; and so on.
; {ej} is short for (WordClassNode "e j") (a set of two words)
;
; What about the CrossSections?
; We expect 9 to be created, 2 each for the first two, and 5 for the last.
; For example, (a, gh) explodes to
;    [g, <a, vh>] and  [h, <a, gv>]
; where [] denotes the CrossSection, and <> denotes the Shape. The "v"
; is the variable node in the Shape (that the germ of the cross-section
; plugs into).
;
; The (c, kaaam) explodes to
;    [k, <c, vaaam>]
;    [a, <c, kvaam>]
;    [a, <c, kavam>]
;    [a, <c, kaavm>]
;    [m, <c, kaaav>]
;
; These should stay consistent with the merged sections. i.e. these
; should reduce to 2 grand-total sections, with appropriate counts.

(define (run-balance WA WB WAB-NAME)

	; Load some data
	(setup-a-b-sections)

	; Define matrix API to the data
	(define pca (make-pseudo-cset-api))
	(define gsc (add-covering-sections pca))

	; Verify that the data loaded correctly
	; We expect 1 sections each on "a" and "b"
	(test-equal 1 (length (gsc 'right-stars (Word "a"))))
	(test-equal 1 (length (gsc 'right-stars (Word "b"))))
	(test-equal 1 (length (gsc 'right-stars (Word "c"))))

	; Get the total count on all Sections
	(define totcnt (fold + 0 (map cog-count (cog-get-atoms 'Section))))

	; Create CrossSections and verify that they got created
	(gsc 'explode-sections)
	(test-equal 9 (length (cog-get-atoms 'CrossSection)))
	(define totcross (fold + 0 (map cog-count (cog-get-atoms 'CrossSection))))

	; Verify that direct-sum object is accessing shapes correctly
	; i.e. the 'explode should have created some CrossSections
	(test-equal 4 (length (gsc 'right-stars (Word "a"))))
	(test-equal 1 (length (gsc 'right-stars (Word "b"))))
	(test-equal 1 (length (gsc 'right-stars (Word "c"))))

	; Should not be any Sections on k,m.
	(test-equal 1 (length (gsc 'right-stars (Word "k"))))
	(test-equal 1 (length (gsc 'right-stars (Word "m"))))

	; We expect a total of 3 Sections
	(test-equal 3 (length (cog-get-atoms 'Section)))

	; --------------------------
	; Merge two sections together.
	(merge gsc WA WB 1)
	(define WC-AB (WordClassNode WAB-NAME))

	; We expect no sections remaining on "a" or "b".
	(test-equal 0 (length (gsc 'right-stars (Word "a"))))
	(test-equal 0 (length (gsc 'right-stars (Word "b"))))
	(test-equal 1 (length (gsc 'right-stars (Word "c"))))

	; We expect one merged section, three crosses
	(test-equal 4 (length (gsc 'right-stars WC-AB)))

	; Of the 3 original Sections, 3 are deleted, and 2 are created,
	; leaving a grand total of 2.
	(test-equal 2 (length (cog-get-atoms 'Section)))

	; Of the 9 original CrossSections, all are deleted outright, and 
	; seven are created to replace them.
	(test-equal 7 (length (cog-get-atoms 'CrossSection)))

	; --------------
	; Validate counts.
	(define tot-ab
		(fold (lambda (atm cnt) (+ cnt (cog-count atm))) 0
		(gsc 'right-stars WC-AB)))
	(define epsilon 1.0e-8)
	(test-approximate (+ cnt-a-gh cnt-b-gh (* 3 cnt-c-aaa)) tot-ab epsilon)

	; -----------------------
	; To gain access to the counts, load them by name.
	(expected-a-b-sections WC-AB)

	(test-approximate (+ cnt-a-gh cnt-b-gh) (cog-count sec-ab-gh) epsilon)
	(test-approximate cnt-c-aaa (cog-count sec-c-aaa) epsilon)

	; Validate counts on CrossSections...
	(test-approximate cnt-c-aaa (cog-count xes-k-c-vaaam) epsilon)
	(test-approximate cnt-c-aaa (cog-count xes-a-c-kvaam) epsilon)
	(test-approximate cnt-c-aaa (cog-count xes-a-c-kavam) epsilon)
	(test-approximate cnt-c-aaa (cog-count xes-a-c-kaavm) epsilon)
	(test-approximate cnt-c-aaa (cog-count xes-m-c-kaaav) epsilon)

	; -----------------------
	; Verify detailed balance
	(test-assert (check-sections gsc epsilon))
	(test-assert (check-crosses gsc epsilon))
	(test-assert (check-shapes gsc epsilon))

	; Verify no change in totals
	(test-approximate totcnt (fold + 0 (map cog-count (cog-get-atoms 'Section)))
		epsilon)
	(test-approximate totcross (fold + 0 (map cog-count (cog-get-atoms 'CrossSection)))
		epsilon)
)

(define t-start-cluster "connector balance test")
(test-begin t-start-cluster)

	; Check both merge orders. Results should be independent of the order.
	(setup-database)
	(run-balance (Word "a") (Word "b") "a b")

	(setup-database)
	(run-balance (Word "b") (Word "a") "b a")
(test-end t-start-cluster)

; ---------------------------------------------------------------
(opencog-test-end)
